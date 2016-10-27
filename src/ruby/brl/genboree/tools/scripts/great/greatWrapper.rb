#!/usr/bin/env ruby
require 'uri'
require 'json'
require 'brl/util/util'
require 'brl/util/emailer'
require 'brl/genboree/tools/toolWrapper'
require 'brl/genboree/tools/wrapperEmailer'
require 'brl/genboree/helpers/dataImport'
require 'brl/util/expander'
require 'brl/util/samTools'
require 'brl/genboree/rest/wrapperApiCaller'
require 'brl/util/convertText'
include BRL::Genboree::REST

module BRL; module Genboree; module Tools; module Scripts
  class HomerWrapper < BRL::Genboree::Tools::ToolWrapper
    VERSION = "1.0"
    COMMAND_LINE_ARGS = { }
    DESC_AND_EXAMPLES = {
      :description  => "This script is used to run GREAT. It is intended to be called from the workbench.",
      :authors      => [ "Sameer Paithankar(paithank@bcm.edu)" ],
      :examples     => [
        "#{File.basename(__FILE__)} --inputFile=filePath",
        "#{File.basename(__FILE__)} -j filePath",
        "#{File.basename(__FILE__)} --help"
      ]
    }
    attr_accessor :exitCode
    # Extract the relevant information to run the job
    # @returns nil
    def processJobConf()
      begin
        @targetUri = @outputs[0]
        @adminEmail = @context['gbAdminEmail']
        @userId = @context['userId']
        @jobId = @context['jobId']
        @jobId = 0 unless @jobId
        @userEmail = @context['userEmail']
        @userLogin = @context['userLogin']
        @toolScriptPrefix = @context['toolScriptPrefix']
        @userFirstName = @context['userFirstName']
        @userLastName = @context['userLastName']
        @scratchDir = @context['scratchDir']
        @scratchDir = "." if(@scratchDir.nil? or @scratchDir.empty?)
        @analysisName = @settings['analysisName']
        @projectUri = nil
        @outputs.each { |output|
          if(@dbApiHelper.extractName(output))
            @dbUri = output
          else
            @projectUri = output
          end
        }
        @dbName = @dbApiHelper.extractName(@dbUri)
        @groupName = @grpApiHelper.extractName(@dbUri)
      rescue => err
        @errUserMsg = "ERROR: Could not set up required variables for running job. "
        @errInternalMsg = err
        @errBacktrace = err.backtrace.join("\n")
        @exitCode = 22
      end
      return @exitCode
    end

    # Runs the script
    # @returns [Integer] exitcode for the process: 0 for success, non-0 otherwise
    def run()
      begin
        # Download input tracks, upload them as files to the target database, unlock them and run GREAT
        targetDbUriObj = URI.parse(@dbUri)
        @resultsFileHash = {}
        @onlyLinks = []
        @inputs.each { |input|
          trkUriObj = URI.parse(input)
          trkName = @trkApiHelper.extractName(input)
          escTrkName = CGI.escape(trkName)
          apiCaller = WrapperApiCaller.new(trkUriObj.host, "#{trkUriObj.path}/annos?format=bed", @userId)
          fileName = "#{CGI.escape(@jobId)}.#{Time.now.to_f}.#{escTrkName}.bed"
          ff = File.open(fileName, 'w')
          apiCaller.get() { |chunk| ff.print(chunk) }
          ff.close()
          if(!apiCaller.succeeded?)
            raise "FATAL ERROR: Could not download input track. API Response:\n#{apiCaller.respBody.inspect}"
          end
          # Strip off track header and empty spaces. GREAT is not so great in handling these.
          rr = File.open(fileName)
          ww = File.open("#{fileName}.final", 'w')
          rr.each_line { |line|
            line.strip!
            next if(line.empty? or line =~ /^#/)
            if(line !~ /^track/)
              line = line.gsub(/ +/, "+")
              ww.print("#{line}\n")
            end
          }
          ww.close()
          rr.close()
          `mv #{fileName}.final #{fileName}`
          # Upload this file to the 'files' area of the target database and assign it a gbKey to unlock it
          fileRsrcPath = "#{targetDbUriObj.path}/file/GREAT/#{CGI.escape(@analysisName)}/#{fileName}"
          apiCaller = WrapperApiCaller.new(targetDbUriObj.host, "#{fileRsrcPath}/data?", @userId)
          apiCaller.put({}, File.open(fileName))
          if(!apiCaller.succeeded?)
            raise "FATAL ERROR: Could not upload data file for track: #{trkName}. API Response:\n#{apiCaller.respBody.inspect}"
          end
          # Unlock the database resource
          payload = { "data" => [{"url" => "http://#{targetDbUriObj.host}#{targetDbUriObj.path}"}]}
          apiCaller.setRsrcPath("/REST/v1/grp/#{CGI.escape(@groupName)}/unlockedResources?")
          apiCaller.put(payload.to_json)
          $stderr.debugPuts(__FILE__, __method__, "GREAT", "unlocking db response=#{apiCaller.respBody.inspect}")
          # Get GREAT result in a machine readable tab-delimited format. This file will be transferred to the target database, the user dragged
          resultFile = "#{CGI.escape(@jobId)}.#{Time.now.to_f}.#{escTrkName}.results.tsv"
          `touch #{resultFile}`
          # Get the genome version of the database
          apiCaller.setRsrcPath(targetDbUriObj.path)
          apiCaller.get()
          @dbVer = apiCaller.parseRespBody['data']['version']
          # Get the gbKey
          apiCaller.setRsrcPath("#{targetDbUriObj.path.chomp('?')}/gbKey?")
          apiCaller.get()
          $stderr.debugPuts(__FILE__, __method__, "GREAT", "getting db gbKey response=#{apiCaller.respBody.inspect}")
          gbKey = apiCaller.parseRespBody['data']['text']
          reqUrl = "http://#{targetDbUriObj.host}#{fileRsrcPath}/data?gbKey=#{gbKey}"
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "reqUrl: #{reqUrl.inspect}")
          `wget -O #{resultFile} "http://bejerano.stanford.edu/great/public/cgi-bin/greatStart.php?outputType=batch&requestSpecies=#{@dbVer}&requestURL=#{CGI.escape(reqUrl)}"`
          if(File.size(resultFile) == 0)
            # Try-again
            attempt = 0
            success = false
            while(attempt < 5 and !success)
              attempt += 1
              sleepTime = (apiCaller.sleepBase * attempt**2)
              $stderr.debugPuts(__FILE__, __method__, "STATUS", "Going to sleep for #{sleepTime} secs.")
              sleep(sleepTime)
              `wget -O #{resultFile} "http://bejerano.stanford.edu/great/public/cgi-bin/greatStart.php?outputType=batch&requestSpecies=#{@dbVer}&requestURL=#{CGI.escape(reqUrl)}"`
              if(File.size(resultFile) != 0)
                success = true
                `grep 'encountered a user error' #{resultFile} > #{resultFile}.hasError.txt`
                if(File.size("#{resultFile}.hasError.txt") != 0)
                  @resultsFileHash[input] = reqUrl
                else
                  @resultsFileHash[input] = reqUrl
                  apiCaller.setRsrcPath("#{targetDbUriObj.path}/file/GREAT/#{CGI.escape(@analysisName)}/#{resultFile}/data?")
                  apiCaller.put({}, File.open(resultFile))
                end
              end
            end
            unless(success)
              @onlyLinks << input
            end
          else
            `grep 'encountered a user error' #{resultFile} > #{resultFile}.hasError.txt`
            if(File.size("#{resultFile}.hasError.txt") != 0)
              @resultsFileHash[input] = reqUrl
              @onlyLinks << input
            else
              @resultsFileHash[input] = reqUrl
              apiCaller.setRsrcPath("#{targetDbUriObj.path}/file/GREAT/#{CGI.escape(@analysisName)}/#{resultFile}/data?")
              apiCaller.put({}, File.open(resultFile))
            end  
          end
          `gzip #{fileName}; gzip #{resultFile}`
          sleep(20) # Give some rest to the GREAT server
        }
        addProjectLink() if(@projectUri)
      rescue => err
        @err = err
        @errUserMsg = err.message
        $stderr.debugPuts(__FILE__, __method__, "ERROR", "Error:\n#{err}\n\nBacktrace:\n#{err.backtrace.join("\n")}")
        @exitCode = 30
      end
      return @exitCode
    end
    
    # Transfers index file containing links for performing live GREAT anlysis to project page
    # @returns nil
    def addProjectLink()
      # First create the index.html page with links for each track
      htmlBuff = "<!DOCTYPE html>
                    <head>
                      <style>
                        table
                        {
                        border-collapse:collapse;
                        }
                        table, td, th
                        {
                        border:1px solid black;
                        }
                      </style>
                    </head>          
                    <body>
                      <div style=\"width:800px; height:1000px;margin-bottom: auto; margin-left: auto; margin-right: auto; margin-top: auto;\" align=\"center\">
                        <div align=\"center\" style=\"margin-top:50px;background-color:white;margin-bottom:100px; overflow: auto;\">
                          <br>&nbsp;<br>
                          <table cellpadding='5'>
                          <caption><b>GREAT</b> - Genomic Regions Enrichment of Annotations Tool</caption>
                            <tr><th>Host</th><th>Group</th><th>Database</th><th>Track</th><th>Link for live analysis</th></tr>
                  "
      @resultsFileHash.each_key { |trkUri|
          reqUrl = @resultsFileHash[trkUri]
          htmlBuff << "<tr>
                        <td>#{@grpApiHelper.extractHost(trkUri)}</td>
                        <td>#{@grpApiHelper.extractName(trkUri)}</td>
                        <td>#{@dbApiHelper.extractName(trkUri)}</td>
                        <td>#{@trkApiHelper.extractName(trkUri)}</td>
                        <td>
                          <a href=\"http://bejerano.stanford.edu/great/public/cgi-bin/greatStart.php?requestSpecies=#{@dbVer}&requestURL=#{CGI.escape(reqUrl)}\" target=\"_blank\">
                          Click here
                          </a>
                        </td>
                      </tr>"
      }
      htmlBuff << "
                          </table>
                        </div>
                        
                      </div>
                    </body>
                  </html>
                  "
      ww = File.open('./index.html', 'w')
      ww.print(htmlBuff)
      ww.close()
      prjUriObj = URI.parse(@projectUri)
      @projectName = @prjApiHelper.extractName(@projectUri)
      apiCaller = WrapperApiCaller.new(prjUriObj.host, "#{prjUriObj.path}/additionalPages/file/#{CGI.escape(@jobId)}/index.html?", @userId)
      apiCaller.put({}, File.open('./index.html'))
      $stderr.puts "Adding link to project page"
      apiCaller = WrapperApiCaller.new(prjUriObj.host, "#{prjUriObj.path}/news?", @userId)
      apiCaller.get()
      raise "ApiCaller 'get' news Failed:\n #{apiCaller.respBody}" if(!apiCaller.succeeded?)
      existingNews = apiCaller.parseRespBody
      existingItems = existingNews['data']
      payload = nil
      if(!existingItems.empty?)
        existingItems.push(
                            {
                              'date' =>  Time.now.localtime.strftime("%m/%d/%Y"),
                              "updateText" => "#{@userFirstName.capitalize} #{@userLastName.capitalize} ran a GREAT (Genomic Regions Enrichment of Annotations Tool) job (#{@jobId}). Click the link below to perform live analysis with GREAT:
                              <ul>
                                <li><a href=\"/projects/#{CGI.escape(@projectName)}/genb%5E%5EadditionalPages/#{CGI.escape(@jobId)}/index.html\">Peform GREAT anlaysis</a></li>
                              </ul>"
                            }
                          )
        payload = {"data" => existingItems}
      else
        newItems = [
                      {
                        'date' =>  Time.now.localtime.strftime("%m/%d/%Y"),
                        "updateText" => "#{@userFirstName.capitalize} #{@userLastName.capitalize} ran a GREAT (Genomic Regions Enrichment of Annotations Tool) job (#{@jobId}). Click the link below to perform live analysis with GREAT:
                        <ul>
                          <li><a href=\"/projects/#{CGI.escape(@projectName)}/genb%5E%5EadditionalPages/#{CGI.escape(@jobId)}/index.html\">Peform GREAT anlaysis</a></li>
                        </ul>"
                      }
  
                  ]
        payload = {"data" => newItems}
      end
      apiCaller = WrapperApiCaller.new(prjUriObj.host, "#{prjUriObj.path}/news?", @userId)
      apiCaller.put(payload.to_json)
      raise "ApiCaller 'put' news failed:\n #{apiCaller.respBody}" if(!apiCaller.succeeded?)
    end


    # Send success email
    # @returns emailObj
    def prepSuccessEmail()
      additionalInfo = "   Target Group: #{@groupName}\n"
      additionalInfo << "   Target Database: #{@dbName}\n\n"
      additionalInfo << "   You can find the output files under GREAT/#{@analysisName} in the target database."
      if(!@onlyLinks.empty?)
        additionalInfo << "\n\nWARNING: The remote GREAT server encountered problems with the following tracks. However, live links have been generated on the project page for all tracks which you can use after some time in case this is a temporary issue:\n"
        @onlyLinks.each { |input|
          additionalInfo << "#{@trkApiHelper.extractName(input)}\n"  
        }
        additionalInfo << "\n"
      end
      emailObject = BRL::Genboree::Tools::WrapperEmailer.new(@toolTitle, @userEmail, @jobId, @userFirstName, @userLastName, analysisName="", inputsText="n/a", outputsText="n/a", settings=nil, additionalInfo, resultFileLocations=nil, resultFileURLs=nil)
      if(@projectUri)
        projHost = URI.parse(@projectUri).host
        emailObject.resultFileLocations = "http://#{projHost}/java-bin/project.jsp?projectName=#{CGI.escape(@prjApiHelper.extractName(@projectUri))}"
      end
      return emailObject
    end

    # Send failure/error email
    # @returns emailObj
    def prepErrorEmail()
      additionalInfo =  "   Target Group: #{@groupName}\n"
      additionalInfo << "   Target Database: #{@dbName}\n\n"
      additionalInfo << "   #{@errUserMsg}"
      emailObject = BRL::Genboree::Tools::WrapperEmailer.new(@toolTitle, @userEmail, @jobId, @userFirstName, @userLastName, analysisName="", inputsText="n/a", outputsText="n/a", settings=nil, additionalInfo, resultFileLocations=nil, resultFileURLs=nil)
      return emailObject
    end

  end
end; end ; end ; end

# IF we are running this file (and not using it as a library), run it:
if($0 and File.exist?($0) and BRL::Script::runningThisFile?($0, __FILE__, true))
  # Argument to main() is your specific class:
  BRL::Genboree::Tools::main(BRL::Genboree::Tools::Scripts::HomerWrapper)
end
