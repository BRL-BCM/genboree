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
      :description  => "This script is used to run HOMER. It is intended to be called from the workbench.",
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
        @homerType = @settings['radioGroup_homerType_btn']
        @genomeVersion = @settings['genomeVersion']
        @analysisName = @settings['analysisName']
        @promoterSet = @settings['promoterSet']
        @groupName = @grpApiHelper.extractName(@outputs[0])
        @dbUri = nil
        @outputs.each { |output|
          if(@dbApiHelper.extractName(output))
            @dbUri = output
          else
            @projectUri = output
          end
        }
        @dbName = @dbApiHelper.extractName(@dbUri)
      rescue => err
        @errUserMsg = "ERROR: Could not set up required variables for running job. "
        @errInternalMsg = err
        @errBacktrace = err.backtrace.join("\n")
        @exitCode = 22
      end
      return @exitCode
    end

    # Runs the script
    # @returns nil
    def run()
      begin
        # Download input track and set it up as a bed/gene list file for HOMER
        trkUriObj = URI.parse(@inputs[0])
        targetDbUriObj = URI.parse(@dbUri)
        apiCaller = WrapperApiCaller.new(trkUriObj.host, "#{trkUriObj.path}/annos?format=bed", @userId)
        fileName = CGI.escape(@trkApiHelper.extractName(@inputs[0]))
        fileName << ".bed"
        ff = File.open(fileName, 'w')
        apiCaller.get() { |chunk| ff.print(chunk) }
        ff.close()
        if(!apiCaller.succeeded?)
          raise "FATAL ERROR: Could not download input track. API Response:\n#{apiCaller.respBody.inspect}"
        end
        `mkdir -p ./scratchDir`
        `mkdir -p ./outputDir`
        homerMotifCmd = "module load homer/4.2; "
        if(@homerType == 'Run against Genome')
          homerMotifCmd << "homerMotifWrapper.rb --verbose -s ./scratchDir -g #{@genomeVersion} -- findMotifsGenome.pl ./#{fileName} %DATA_DIR%  ./outputDir "
          if(@settings.key?('-mask'))
            homerMotifCmd << " -mask "            
          end
          homerMotifCmd << " -size #{@settings['-size']} " if(@settings.key?('-size'))
          homerMotifCmd << " -h " if(@settings.key?('-h'))
          homerMotifCmd << " -local #{@settings['-local']}" if(@settings.key?('-local'))
          homerMotifCmd << " -redundant #{@settings['-redundant']}" if(@settings.key?('-redundant'))
          homerMotifCmd << " -oligo " if(@settings.key?('-oligo'))
          homerMotifCmd << " -preparse " if(@settings.key?('-preparse'))
          if(@settings['normalization'] == '-gc')
            homerMotifCmd << " -gc " 
          else
            homerMotifCmd << " -cpg "
          end
        else
          `grep -v 'track name' #{fileName} > #{fileName}.tmp; cut -f 4 #{fileName}.tmp | sort -d | uniq > #{fileName}.names; rm -f #{fileName}.tmp`
          homerMotifCmd << "homerMotifWrapper.rb --verbose -s ./scratchDir -g #{@promoterSet} -- findMotifs.pl ./#{fileName}.names %DATA_DIR% ./outputDir "
          homerMotifCmd << " -b " if(@settings.key?('-b'))
          homerMotifCmd << " -nogo " if(@settings.key?('-nogo'))
          homerMotifCmd << " -peaks " if(@settings.key?('-peaks'))
          homerMotifCmd << " -min #{@settings['-min']} " if(@settings.key?('-min'))
          homerMotifCmd << " -max #{@settings['-max']} " if(@settings.key?('-max'))
          homerMotifCmd << " -noredun " if(@settings.key?('-noredun'))
          homerMotifCmd << " -cpg " if(@settings['normalization'] == '-cpg')
        end
        homerMotifCmd << " -len #{@settings['-len']} -S #{@settings['-S']} -mis #{@settings['-mis']} "
        homerMotifCmd << " -norevopp " if(@settings.key?('-norevopp'))
        homerMotifCmd << " -nomotif " if(@settings.key?('-nomotif'))
        homerMotifCmd << " -rand " if(@settings.key?('-rand'))
        homerMotifCmd << " -dumpFasta " if(@settings.key?('-dumpFasta'))
        homerMotifCmd << " -fdr #{@settings['-fdr']}" if(@settings.key?('-fdr') and !@settings['-fdr'].empty?)
        homerMotifCmd << " -noweight " if(@settings.key?('-noweight'))
        homerMotifCmd << " -nlen #{@settings['-nlen']}" if(@settings.key?('-nlen'))
        homerMotifCmd << " -olen #{@settings['-olen']}" if(@settings.key?('-olen') and !@settings['-olen'].empty?)
        homerMotifCmd << " -e #{@settings['-e']}" if(@settings.key?('-e'))
        homerMotifCmd << " -mset #{@settings['-mset']} "
        homerMotifCmd << " -basic " if(@settings.key?('-basic'))
        homerMotifCmd << " -bits " if(@settings.key?('-bits'))
        homerMotifCmd << " -nocheck " if(@settings.key?('-nocheck'))
        homerMotifCmd << " -noknown " if(@settings.key?('-noknown'))
        homerMotifCmd << " > homer.out 2> homer.err"
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Running command:\n#{homerMotifCmd}")
        `#{homerMotifCmd}`
        if($?.exitstatus != 0)
          # Something went wrong. Copy the homer.err file to the target folder. This may help the user/admins look into the problem
          errMsg = "FATAL ERROR: HOMER exited with non 0 exit status."
          if(File.exists?('./homer.err'))
            errMsg <<  " Please check the homer.err file under HOMER/#{@analysisName} in the target database for additional information."
            apiCaller = WrapperApiCaller.new(targetDbUriObj.host, "#{targetDbUriObj.path}/file/HOMER/#{CGI.escape(@analysisName)}/homer.err/data?", @userId)
            apiCaller.put({}, File.open('./homer.err'))
            raise errMsg
          end
        else # HOMER ran successfully. Copy output files to target database
          Dir.chdir('./outputDir')
          # Remove the link to geneOntology if relevant html file is missing
          if(!File.exists?('./geneOntology.html'))
            `grep -v 'geneOntology.html' homerResults.html > homerResultsWithoutGOLink.html; mv homerResultsWithoutGOLink.html homerResults.html`
            `grep -v 'geneOntology.html' knownResults.html > knownResultsWithoutGOLink.html; mv knownResultsWithoutGOLink.html knownResults.html`
          end
          `zip -r homerOutputFiles.zip *`
          apiCaller = WrapperApiCaller.new(targetDbUriObj.host, "#{targetDbUriObj.path}/file/HOMER/#{CGI.escape(@analysisName)}/homerOutputFiles.zip/data?", @userId)
          apiCaller.put({}, File.open('./homerOutputFiles.zip'))
          Dir.chdir('../')
        end
        addProjectLink()
      rescue => err
        @err = err
        @errUserMsg = err.message
        $stderr.debugPuts(__FILE__, __method__, "ERROR", "Error:\n#{err}\n\nBacktrace:\n#{err.backtrace.join("\n")}")
        @exitCode = 30
      end
      return @exitCode
    end
    
    # Transfers output zip file created by HOMER to project area and creates link
    # @returns nil
    def addProjectLink()
      prjUriObj = URI.parse(@projectUri)
      @projectName = @prjApiHelper.extractName(@projectUri)
      apiCaller = WrapperApiCaller.new(prjUriObj.host, "#{prjUriObj.path}/additionalPages/file/#{CGI.escape(@jobId)}/homerOutputFiles.zip?extract=true", @userId)
      apiCaller.put({}, File.open('./outputDir/homerOutputFiles.zip'))
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
                              "updateText" => "#{@userFirstName.capitalize} #{@userLastName.capitalize} ran a HOMER job (#{@jobId}) and the results are available at the link below.
                              <ul>
                                <li><a href=\"/projects/#{CGI.escape(@projectName)}/genb%5E%5EadditionalPages/#{CGI.escape(@jobId)}/homerResults.html\">Link to Homer Results</a></li>
                              </ul>"
                            }
                          )
        payload = {"data" => existingItems}
      else
        newItems = [
                      {
                        'date' =>  Time.now.localtime.strftime("%m/%d/%Y"),
                        "updateText" => "#{@userFirstName.capitalize} #{@userLastName.capitalize} ran a HOMER job (#{@jobId}) and the results are available at the link below.
                        <ul>
                          <li><a href=\"/projects/#{CGI.escape(@projectName)}/genb%5E%5EadditionalPages/#{CGI.escape(@jobId)}/homerResults.html\">Link to Homer Results</a></li>
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
      additionalInfo << "   You can find the resultant zip file containing all the output files from HOMER under HOMER/#{@analysisName} in the target database."
      emailObject = BRL::Genboree::Tools::WrapperEmailer.new(@toolTitle, @userEmail, @jobId, @userFirstName, @userLastName, analysisName="", inputsText="n/a", outputsText="n/a", settings=nil, additionalInfo, resultFileLocations=nil, resultFileURLs=nil)
      projHost = URI.parse(@projectUri).host
      emailObject.resultFileLocations = "http://#{projHost}/java-bin/project.jsp?projectName=#{CGI.escape(@prjApiHelper.extractName(@projectUri))}"
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
