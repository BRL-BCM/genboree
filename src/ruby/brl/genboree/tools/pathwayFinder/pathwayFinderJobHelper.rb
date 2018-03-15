require 'json'
require 'brl/util/util'
require 'brl/genboree/genboreeUtil'
require 'uri'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require 'brl/genboree/rest/helpers/sampleSetApiUriHelper'
require 'brl/genboree/rest/helpers/fileApiUriHelper'
require 'brl/genboree/tools/workbenchJobHelper'
require 'brl/genboree/rest/wrapperApiCaller'
include BRL::Genboree::REST

module BRL ; module Genboree ; module Tools
  class PathwayFinderJobHelper < WorkbenchJobHelper

    TOOL_ID = 'pathwayFinder'

    # Instance vars that should be overridden to launch the job
    def initialize(toolIdStr, genbConf=nil, dbu=nil, *args)
      super(toolIdStr, genbConf, dbu, args)
      @tempArea = ENV['TMPDIR']
    end

    def runInProcess()
      success = true
      # Set up dbrc-related variables - also done below in run() method, since we need user / pass again and we don't want to save authentication info in instance variables
      dbrcFile = File.expand_path(ENV['DBRC_FILE'])
      user = pass = nil
      suDbDbrc = BRL::Genboree::GenboreeUtil.getSuperuserDbrc(@genbConf, dbrcFile)
      user = suDbDbrc.user
      pass = suDbDbrc.password
      host = suDbDbrc.driver.split(/:/).last
      @toolVersion = @toolConf.getSetting('info', 'version')
      # Set up anticipated data repository options
      # Cut off first two chars if anticipated data repo is 0_None - 0_ was added only for UI reasons 
      workbenchJobObj.settings['anticipatedDataRepo'] = workbenchJobObj.settings['anticipatedDataRepo'][2..-1] if(workbenchJobObj.settings['anticipatedDataRepo'] == "0_None")
      # If anticipatedDataRepo is "None", then we make sure that other data repo is nil, data repo submission is not for DCC, and dbGaP is not applicable (not sure about this last part)
      if(workbenchJobObj.settings['anticipatedDataRepo'] == "None")
        workbenchJobObj.settings['otherDataRepo'] = nil
        workbenchJobObj.settings['dataRepoSubmissionCategory'] = "Samples Not Meant for Submission to DCC"
        workbenchJobObj.settings['dbGaP'] = "Not Applicable"
      else
        # We make dbGaP option not applicable if the anticipated repo doesn't include dbGaP
        workbenchJobObj.settings['dbGaP'] = "Not Applicable" if(workbenchJobObj.settings['anticipatedDataRepo'] != "dbGaP" and workbenchJobObj.settings['anticipatedDataRepo'] != "Both GEO & dbGaP")
        # We make other data repo nil if anticipated data repo is not "Other"
        workbenchJobObj.settings['otherDataRepo'] = nil if(workbenchJobObj.settings['anticipatedDataRepo'] != "Other")
      end
      # Cut off first two chars if grant number is primary, as that means it has a prefix of 0_ (added only for UI reasons)
      workbenchJobObj.settings['grantNumber'] = workbenchJobObj.settings['grantNumber'][2..-1] if(workbenchJobObj.settings['grantNumber'].include?("Primary"))
      # Now, we'll set up our variables for the tool usage doc
      @exRNAInternalKBHost = @genbConf.exRNAInternalKBHost
      @exRNAInternalKBGroup = @genbConf.exRNAInternalKBGroup
      @exRNAInternalKBName = @genbConf.exRNAInternalKBName
      @piCodesColl = @genbConf.exRNAInternalKBPICodesColl
      @erccToolUsageColl = @genbConf.exRNAInternalKBToolUsageColl
      @piName = workbenchJobObj.settings['piName']
      if(workbenchJobObj.settings['grantNumber'] == "Non-ERCC Funded Study")
        @grantNumber = workbenchJobObj.settings['grantNumber']
      else 
        @grantNumber = workbenchJobObj.settings['grantNumber'].split(" ")[0]
      end
      @piID = workbenchJobObj.settings['piID']
      @platform = "Genboree Workbench"
      @processingPipeline = "Pathway Finder"
      @anticipatedDataRepo = workbenchJobObj.settings['anticipatedDataRepo']
      @otherDataRepo = workbenchJobObj.settings['otherDataRepo']
      @dataRepoSubmissionCategory = workbenchJobObj.settings['dataRepoSubmissionCategory']
      @dbGaP = workbenchJobObj.settings['dbGaP']
      @submitterOrganization = ""
      @piOrganization = ""
      @coPINames = ""
      @rfaTitle = ""
      if(@piName == "Non-ERCC PI")
        apiCaller = ApiCaller.new(host, "/REST/v1/usr/#{@userLogin}", user, pass)
        apiCaller.initInternalRequest(@rackEnv, genbConf.machineNameAlias) if(@rackEnv)
        apiCaller.get()
        @submitterOrganization = apiCaller.parseRespBody["data"]["institution"]
        @submitterOrganization = "N/A" if(@submitterOrganization.empty?)
        @piOrganization = "N/A (Submitter organization: #{@submitterOrganization})"
        @rfaTitle = "Non-ERCC Submission"
      else
        # Grab PI document to find some additional information for tool usage doc
        apiCaller = ApiCaller.new(@exRNAInternalKBHost, "/REST/v1/grp/{grp}/kb/{kb}/coll/{coll}/doc/{doc}", user, pass)
        apiCaller.initInternalRequest(@rackEnv, genbConf.machineNameAlias) if(@rackEnv)
        apiCaller.get({:grp => @exRNAInternalKBGroup, :kb => @exRNAInternalKBName, :coll => @piCodesColl, :doc => @piID})
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "API RESPONSE: #{apiCaller.respBody.inspect}")
        piDoc = BRL::Genboree::KB::KbDoc.new(apiCaller.parseRespBody["data"])
        @piOrganization = piDoc.getPropVal("ERCC PI Code.Organization")
        unless(@grantNumber == "Non-ERCC Funded Study")
          grantDetails = piDoc.getPropItems("ERCC PI Code.Grant Details")
          grantDetails.each { |currentGrant|
            currentGrant = BRL::Genboree::KB::KbDoc.new(currentGrant)
            currentGrantNumber = currentGrant.getPropVal("Grant Number")
            if(currentGrantNumber == @grantNumber)
              @rfaTitle = currentGrant.getPropVal("Grant Number.RFA")
              @coPINames = currentGrant.getPropVal("Grant Number.Co PI Names") if(currentGrant.getPropVal("Grant Number.Co PI Names"))
            end
          }
        else
          @rfaTitle = "Non-ERCC Submission"
        end
      end
      # Used in tool usage doc to flag whether run was successful or not
      @successfulRun = false
      # Grab file inputs from Workbench
      inputs = @workbenchJobObj.inputs
      # errorMsg will hold any error messages that we find below
      errorMsg = ""
      # NOTE: Right now (and maybe permanently), there is only one input file for this tool
      inputs.each { |input|
        # Grab file name
        fileBase = @fileApiHelper.extractName(input)
        fileBaseName = File.basename(fileBase)
        tmpFile = "#{@tempArea}/#{fileBaseName.makeSafeStr(:ultra)}"
        # Parse URI and grab resource path
        targetUri = URI.parse(input)
        rsrcPath = targetUri.path
        rsrcPath << "/data?"
        # Create the API caller
        apiCaller = WrapperApiCaller.new(targetUri.host, rsrcPath, @userId)
        # Making internal API call
        apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
        # Download the target file
        ff = File.open(tmpFile, 'w')
        apiCaller.get() { |chunk| ff.print(chunk) }
        ff.close() 
        @sampleName = fileBaseName
        # If the API call didn't succeed, then we want to print information about the error and set success to false
        unless(apiCaller.succeeded?)
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "apiCaller failed: #{apiCaller.parseRespBody}")
          errorMsg = "The API call to retrieve your file failed. Please contact a DCC admin (<a href=\"mailto:sailakss@bcm.edu\">sailakss@bcm.edu</a> or <a href=\"mailto:thistlew@bcm.edu\">thistlew@bcm.edu</a>) for help."
          # We'll clean up the input file if the download fails
          `rm -rf #{tmpFile}`
        # Otherwise, if the API call did succeed, then we will run our pathwayFinder script on that file
        else
          begin
            # Create temporary sub job directory for pathway finder results
            @subJobDir = "#{@tempArea}/#{File.basename(tmpFile)}_temp"
            `mkdir #{@subJobDir}`
            # Move tmpFile to this directory
            baseNameOfTmpFile = File.basename(tmpFile)
            `mv #{tmpFile} #{@subJobDir}/#{baseNameOfTmpFile}`
            tmpFile = "#{@subJobDir}/#{baseNameOfTmpFile}"
            # We'll convert the file to be pathwayFinder compatible if it's in exceRpt format
            contents = File.read(tmpFile)
            newContents = ""
            contents.each_line { |currentLine|
              currentLineTabbed = currentLine.split("\t")
              if(currentLineTabbed[0].include?(":"))
                newContents << "#{currentLineTabbed[0].split(":")[0]}\n"
              else
                newContents << currentLine
              end
            }
            File.open(tmpFile, 'w') { |file| file.write(newContents) }
            # Set up .out / .err file names and run pathway finder
            @outFile = "#{@subJobDir}/#{File.basename(tmpFile)}.out"
            @errFile = "#{@subJobDir}/#{File.basename(tmpFile)}.err"
            command = "source /usr/local/brl/local/etc/bashrc ; module load pathwayFinder/1.0 ; python $PATHWAYFINDER #{tmpFile} -o #{@subJobDir}/ -d True 1>#{@outFile} 2>#{@errFile}"
            $stderr.debugPuts(__FILE__, __method__, "STATUS", "Launching command: #{command}")
            exitStatus = system(command)
            $stderr.debugPuts(__FILE__, __method__, "STATUS", "Exit status is: #{exitStatus}")
            # Figure out if error occurred
            failedRun = findError(exitStatus)
            if(failedRun)
              errorMsg = "We were unable to complete the pathway finder on your input file, as we encountered an error.\nAre you sure that your input text file is in the proper format?\nYour first column in your text file should be a list of human miRNA identifiers.\nIt is also possible that your miRNA(s) were not associated with any pathways present in the miRTarBase 2016 database.\n\nSee more information about your error below:\n\n"
              unless(File.zero?(@errFile))
                errorMsg << File.read(@errFile)
              else 
                errorMsg << File.read(@outFile)
              end
            else
              # Read contents of pathways html file into ruby variable
              htmlResponse = File.read("#{@subJobDir}/pathways.html")
              # Delete unwanted HTML code (especially the script line - that line breaks everything!)
              htmlResponse.gsub!("<html>", "")
              htmlResponse.gsub!("</html>", "")
              htmlResponse.gsub!("<body>", "")
              htmlResponse.gsub!("</body>", "")
              htmlResponse.gsub!("<script src=\"https://cdnjs.cloudflare.com/ajax/libs/d3/3.5.6/d3.min.js\"></script>", "")
              # Save resulting code in @workbenchJobObj
              @workbenchJobObj.settings['htmlResponse'] = htmlResponse
              @successfulRun = true
            end
          ensure
            # Make sure that we delete temporary sub job directory
            `rm -rf #{@subJobDir}`
            @jobId = "wbJob-pathwayFinder-"
            firstPartOfId = ""; 6.times{firstPartOfId << ((rand(2)==1?65:97) + rand(25)).chr}
            @jobId << firstPartOfId
            secondPartOfId = "-"; 4.times{secondPartOfId << rand(10).to_s}
            @jobId << secondPartOfId
            output = workbenchJobObj.outputs[0]
            @groupName = @grpApiHelper.extractName(input)
            submitToolUsageDoc(user, pass)
          end
        end
      }
      # If we do not succeed, then we will set up an error message for the user
      if(@workbenchJobObj.settings['htmlResponse'].nil? or @workbenchJobObj.settings['htmlResponse'].empty?)
        @workbenchJobObj.settings['errorMsg'] = errorMsg
      end
      # Finally, we return success boolean (dummy in this case - real information about error is found in message to user)
      return success
    end

    # Method to detect errors
    # @param [boolean] exitStatus indicating if the system() call "succeeded" or not.
    # @return [boolean] indicating if a PathwayFinder error was found or not.
    def findError(exitStatus)
      retVal = true
      errorMessages = nil
      # Check the obvious things first. Outright failure or putting error messages on stderr:
      if(exitStatus)
        # So far, so good. Look for ERROR lines on stdout.
        cmd = "grep -i \"ERROR\" #{@outFile} | grep -v \"Backtrace\""
        errorMessages = `#{cmd}`
        if(errorMessages.strip.empty?)
          retVal = false
        end
      end
      return retVal
    end

    ########## METHODS RELATED TO TOOL USAGE DOC ##########   
 
    # Submits a document to exRNA Internal KB in order to keep track of ERCC tool usage
    # @return [nil]
    def submitToolUsageDoc(user, pass)
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Currently uploading tool usage doc")
      # Create KB doc for tool usage and fill it out
      toolUsage = BRL::Genboree::KB::KbDoc.new({})
      toolUsage.setPropVal("ERCC Tool Usage", @jobId)
      toolUsage.setPropVal("ERCC Tool Usage.Status", "Add")
      toolUsage.setPropVal("ERCC Tool Usage.Job Date", "")
      toolUsage.setPropVal("ERCC Tool Usage.Submitter Login", @userLogin)
      toolUsage.setPropVal("ERCC Tool Usage.PI Name", @piName)
      toolUsage.setPropVal("ERCC Tool Usage.Grant Number", @grantNumber)
      toolUsage.setPropVal("ERCC Tool Usage.RFA Title", @rfaTitle)
      toolUsage.setPropVal("ERCC Tool Usage.Organization of PI", @piOrganization)
      toolUsage.setPropVal("ERCC Tool Usage.Co PI Names", @coPINames) unless(@coPINames.empty?)
      toolUsage.setPropVal("ERCC Tool Usage.Genboree Group Name", @groupName)
      toolUsage.setPropVal("ERCC Tool Usage.Genboree Database Name", "[Not Used]")
      toolUsage.setPropVal("ERCC Tool Usage.Samples Processed Through ERCC Pipeline", 1)
      runItem = BRL::Genboree::KB::KbDoc.new({})
      runItem.setPropVal("Sample Name", @sampleName)
      sampleStatus = ""
      successfulSamples = 0
      failedSamples = 0
      if(@successfulRun)
        sampleStatus = "Completed"
        successfulSamples += 1
      else 
        sampleStatus = "Failed"
        failedSamples += 1
      end
      runItem.setPropVal("Sample Name.Sample Status", sampleStatus)
      toolUsage.addPropItem("ERCC Tool Usage.Samples Processed Through ERCC Pipeline", runItem)
      toolUsage.setPropVal("ERCC Tool Usage.Number of Successful Samples", successfulSamples)
      toolUsage.setPropVal("ERCC Tool Usage.Number of Failed Samples", failedSamples)
      toolUsage.setPropVal("ERCC Tool Usage.Platform", @platform)
      toolUsage.setPropVal("ERCC Tool Usage.Processing Pipeline", @processingPipeline)
      toolUsage.setPropVal("ERCC Tool Usage.Processing Pipeline.Version", @toolVersion)
      toolUsage.setPropVal("ERCC Tool Usage.Anticipated Data Repository", @anticipatedDataRepo)
      toolUsage.setPropVal("ERCC Tool Usage.Anticipated Data Repository.Other Data Repository", @otherDataRepo) if(@otherDataRepo)
      toolUsage.setPropVal("ERCC Tool Usage.Anticipated Data Repository.Submission Category", @dataRepoSubmissionCategory)
      toolUsage.setPropVal("ERCC Tool Usage.Anticipated Data Repository.Project Registered by PI with dbGaP?", @dbGaP)
      # Upload doc
      apiCaller = ApiCaller.new(@exRNAInternalKBHost, "/REST/v1/grp/{grp}/kb/{kb}/coll/{coll}/docs?", user, pass)
      payload = {"data" => toolUsage}
      apiCaller.put({:grp => @exRNAInternalKBGroup, :kb => @exRNAInternalKBName, :coll => @erccToolUsageColl}, payload.to_json)
      # If doc upload fails, raise error
      unless(apiCaller.succeeded? and apiCaller.parseRespBody["data"]["docs"]["properties"]["invalid"]["items"].empty?)
        @errUserMsg = "ApiCaller failed: call to upload tool usage doc failed."
        $stderr.debugPuts(__FILE__, __method__, "ERROR", "ApiCaller failed to upload tool usage doc: #{apiCaller.respBody.inspect}")
        raise @errUserMsg
      else
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Successfully uploaded tool usage doc")
      end
      return
    end

  end
end ; end ; end # module BRL ; module Genboree ; module Tools
