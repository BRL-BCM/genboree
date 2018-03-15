require 'brl/genboree/tools/workbenchRulesHelper'
require 'brl/genboree/tools/workbenchFormHelper'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require 'brl/genboree/rest/helpers/fileApiUriHelper'
require 'uri'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/rest/apiCaller'
require "brl/genboree/helpers/sniffer"
include BRL::Genboree::REST

module BRL ; module Genboree ; module Tools
  class DESeq2RulesHelper < WorkbenchRulesHelper
    TOOL_ID = 'DESeq2'
    
    def rulesSatisfied?(wbJobEntity, sectionsToSatisfy=[ :inputs, :outputs, :context, :settings ], toolIdStr=@toolIdStr)
      # Grab necessary variables for grabbing submitter's ERCC info (used for tool usage doc)
      exRNAInternalKBHost = @genbConf.exRNAInternalKBHost
      wbJobEntity.settings['exRNAInternalKBHost'] = exRNAInternalKBHost
      exRNAInternalKBGroup = @genbConf.exRNAInternalKBGroup
      wbJobEntity.settings['exRNAInternalKBGroup'] = exRNAInternalKBGroup
      exRNAInternalKBName = @genbConf.exRNAInternalKBName
      wbJobEntity.settings['exRNAInternalKBName'] = exRNAInternalKBName
      exRNAInternalKBPICodesColl = @genbConf.exRNAInternalKBPICodesColl
      wbJobEntity.settings['exRNAInternalKBPICodesColl'] = exRNAInternalKBPICodesColl
      submitterPropPath = "ERCC PI Code.Submitters.Submitter ID.Submitter Login"
      # We also save tool usage collection name for filling out tool usage doc later on
      exRNAInternalKBToolUsageColl = @genbConf.exRNAInternalKBToolUsageColl
      wbJobEntity.settings['exRNAInternalKBToolUsageColl'] = exRNAInternalKBToolUsageColl
      # Grab dbrc info for making API call to PI Codes collection
      user = @superuserApiDbrc.user
      pass = @superuserApiDbrc.password
      # Set up various variables that will be used in UI and wrapper
      readCountsFile = nil
      identifiersFile = nil
      sampleDescriptors = []
      factorLevelsForSampleDescriptors = {}
      @flagForWebServerParsing = false
      # Apply basic rules from the rules file (counts, basic types, other simple things)
      rulesSatisfied = super(wbJobEntity, sectionsToSatisfy, toolIdStr)
      errorMsgArr = []
      asciiFiles = []
      coreResultFiles = []
      outputs = wbJobEntity.outputs
      # If we pass that initial check, we need to make sure that all of our files are ASCII or archived files (and non-empty)
      if(rulesSatisfied)
        # Grab inputs
        fileList = @fileApiHelper.expandFileContainers(wbJobEntity.inputs, @userId)
        wbJobEntity.inputs = fileList
        inputs = wbJobEntity.inputs
        # Temp fix to skip various checks if submission comes from Atlas
        inputs.each { |currentFileName|
          @flagForWebServerParsing = true if(currentFileName.include?("ExRNAAtlasDeseq2"))
        }
        # This tool requires at least two files, so we need to reject the job if the user tried to submit 0 or 1
        # This problem is partially handled by workbench.rules.json, but it's possible to get past that restriction (for example, by submitting a folder that contains only one file)
        unless(inputs.size() >= 2)
          errorMsgArr.push("INVALID NUMBER OF INPUTS: Your inputs are not correct. You can either submit 1) exactly TWO input text files for your DESeq2 job (one containing miRNA read counts and one containing sample descriptors) or 2) a text file containing sample descriptors and also some number of CORE_RESULTS archives from exceRpt. Your miRNA read count text file will be created from these CORE_RESULTS archives.")
          rulesSatisfied = false
        else
          # This tool can theoretically have hundreds or even thousands of inputs.
          # We can't sniff that many inputs on web server (it will result in a time out), so we skip the sniffing step if the number of inputs is greater than 20.
          if(inputs.size <= 20 and !@flagForWebServerParsing)
            # We need to check each input to make sure that it's non-empty and text
            inputs.each { |file|
              fileSizeSatisfied = true
              fileSizeSatisfied = checkFileSize(errorMsgArr, file)
              if(fileSizeSatisfied)
                fileFormatSatisfied = sniffFileFormat(errorMsgArr, file, asciiFiles, coreResultFiles)
              end
            }
          else
            # Because the user hasn't submitted a miRNA read counts file (since he/she is most likely submitting a bunch of CORE_RESULTS archives),
            # we can't do on-the-fly parsing of the user's read counts file, as it hasn't been created yet!
            @flagForWebServerParsing = true
            # If the number of inputs is greater than 20, then we know that we want to run the post-processing tool in the DESeq2 wrapper.
            # The user most likely submitted CORE_RESULT archives / a sample descriptor document.
            wbJobEntity.settings['runPostProcessingTool'] = true
          end
        end
      end
      rulesSatisfied = false unless(errorMsgArr.empty?)
      # We only want to check the number of ASCII / CORE_RESULTS archive files if the number of inputs is less than or equal to 20.
      # Otherwise, we haven't yet checked which files are ASCII and which files are CORE_RESULTS archives (since we didn't sniff anything), so we have to skip this check!
      if(rulesSatisfied and inputs.size <= 20 and !@flagForWebServerParsing)
        if(asciiFiles.size == 2 and coreResultFiles.size == 0)
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "User has submitted two ASCII files and no CORE_RESULTS archives. This is an acceptable combination of inputs. We will not run PPR in the DESeq2 wrapper.")
          wbJobEntity.settings['runPostProcessingTool'] = false
        elsif(asciiFiles.size == 1 and coreResultFiles.size > 0)
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "User has submitted one ASCII file and at least one CORE_RESULTS archive. This is an acceptable combination of inputs. We will run PPR in the DESeq2 wrapper.")
          wbJobEntity.settings['runPostProcessingTool'] = true
        else 
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "User has submitted some unacceptable combination of input files. Job is rejected.")
          errorMsgArr.push("INVALID NUMBER OF INPUTS: Your inputs are not correct. You can either submit 1) exactly TWO input text files for your DESeq2 job (one containing miRNA read counts and one containing sample descriptors) or 2) a text file containing sample descriptors and some number of CORE_RESULTS archives from exceRpt. Your miRNA read count text file will be created from these CORE_RESULTS archives.")
          rulesSatisfied = false
        end
      end
      # At this point, if rules are still satisfied, and @flagForWebServerParsing is false, then we have two input files that are ASCII and non-empty.
      # We should now do some more specific checking to ensure that the two input files are in the correct format for DESeq2.
      # We will only do this checking HERE, in this RulesHelper, if the files are each under a megabyte in size (otherwise, it'll be too taxing on the web server).
      if(rulesSatisfied and !@flagForWebServerParsing)
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Parsing files to make sure that they're in correct format for DESeq2.")
        # Grab info about both files
        firstFile = URI.parse(inputs[0])
        secondFile = URI.parse(inputs[1])
        # Grab data for first file
        apiCaller = ApiCaller.new(firstFile.host, "#{firstFile.path}/data?", @hostAuthMap)
        apiCaller.initInternalRequest(@rackEnv, genbConf.machineNameAlias) if(@rackEnv)
        apiCaller.get()
        # Split up file into individual lines
        firstFile = apiCaller.respBody().gsub(/\r\n?/, "\n").split("\n")
        # Remove header lines and blank lines
        firstFile =  firstFile.select { |currentToken| currentToken =~ /^[^\r\n]/ }
        # Split up file into individual tab-delimited elements on lines
        firstFile.map! { |currentToken| currentToken.split("\t") }
        # Grab data for second file
        apiCaller = ApiCaller.new(secondFile.host, "#{secondFile.path}/data?", @hostAuthMap)
        apiCaller.initInternalRequest(@rackEnv, genbConf.machineNameAlias) if(@rackEnv)
        apiCaller.get()
        # Split up file into individual lines
        secondFile = apiCaller.respBody().gsub(/\r\n?/, "\n").split("\n")
        # Remove header lines
        secondFile = secondFile.select { |currentToken| currentToken =~ /^[^\r\n]/ }
        # Split up file into individual tab-delimited elements on lines
        secondFile.map! { |currentToken| currentToken.split("\t") }
        # Strip all tokens of extra white space
        firstFile.each { |currentArray| currentArray.map! { |currentToken| currentToken.strip } }
        secondFile.each { |currentArray| currentArray.map! { |currentToken| currentToken.strip } }
        # Grab column headers for each file
        firstFileColumnHeaders = firstFile[0]
        secondFileColumnHeaders = secondFile[0]
        # Grab row headers for each file 
        firstFileRowHeaders = []
        secondFileRowHeaders = []
        firstFile.each { |currentLine|
          firstFileRowHeaders << currentLine[0]
        }
        secondFile.each { |currentLine|
          secondFileRowHeaders << currentLine[0]
        }
        # Let's delete the first element from each of these (since it's blank or something else unnecessary that isn't a row or column name)
        firstFileRowHeaders.shift()
        secondFileRowHeaders.shift()
        firstFileColumnHeaders.shift()
        secondFileColumnHeaders.shift()
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "First file's row headers: #{firstFileRowHeaders.inspect}")
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Second file's row headers: #{secondFileRowHeaders.inspect}")
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "First file's column headers: #{firstFileColumnHeaders.inspect}")
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Second file's column headers: #{secondFileColumnHeaders.inspect}")
        # Our main check is that the column headers for the read counts file must be the same as the row headers for the sample descriptors file.
        if(firstFileColumnHeaders.sort() == secondFileRowHeaders.sort())
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Files are in correct format.")
          wbJobEntity.settings['readCountsFileName'] = inputs[0]
          wbJobEntity.settings['sampleDescriptorsFileName'] = inputs[1]
          readCountsFile = firstFile
          identifiersFile = secondFile
        elsif(secondFileColumnHeaders.sort() == firstFileRowHeaders.sort())
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Files are in correct format.")
          wbJobEntity.settings['readCountsFileName'] = inputs[1]
          wbJobEntity.settings['sampleDescriptorsFileName'] = inputs[0]
          readCountsFile = secondFile
          identifiersFile = firstFile
        else
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Files are not in correct format.")
          rulesSatisfied = false
          errorMsgArr.push("WRONG INPUT FORMAT: Your two input files are not in the correct format. The column headers in your file containing read counts must match the row headers in your file containing sample descriptors. Also, your documents should not contain any header lines (lines that begin with #). The one exception to this rule is the first line of your file (which should contain the column names).")
        end
      end
      # Now, we've checked that our files are in the right format, and we know which input is the read counts file and which input is the sample identifiers file
      # Next, we'll figure out the different sample identifiers (condition, biofluid) and their respective factor levels (example: control vs. AD vs. PD for condition identifier)
      # THIS IS CURRENTLY DISABLED, AS IT'S NOT NECESSARY FOR THE FIRST VERSION OF THE TOOL!
      #if(rulesSatisfied)
        # The header line will contain the different sample identifiers that we will use as keys in our factorLevelsForSampleDescriptors hash
        #headerLine = false
        #identifiersFile.each { |currentLine|
          # If we haven't yet seen the header line, then we will save its sample identifiers in the sampleDescriptors array.
          # The index associated with each sample identifier will also correspond to its different factor levels (control, AD, PD, etc.) found throughout the file
          # In other words, the index of the column header is the same as the index of the values within that column!
          #unless(headerLine)
            #currentLine.each_with_index { |currentSampleIdentifier, idx|
              #next if(idx == 0) # First column is just going to be blank if file is in correct format
              #sampleDescriptors[idx] = currentSampleIdentifier
            #}
            # There's only one header line, so we set headerLine to true after we parse it
            #headerLine = true
          #else
            # Now, we've read the header line and saved all the possible sample identifiers (column headers).
            # We will now parse the file in full. Each column (other than the first one, which is the sample name) will contain a factor level for its respective sample identifier.
            # We'll save all of the factor levels in our factorLevelsForSampleDescriptors hash.
            #currentLine.each_with_index { |currentFactorLevel, idx|
              #next if(idx == 0) # The first column is always the sample names, so we will skip the first column for each row
              #unless(factorLevelsForSampleDescriptors[sampleDescriptors[idx]])
                #factorLevelsForSampleDescriptors[sampleDescriptors[idx]] = [] # We will go ahead and create an empty array for each new sample identifier
              #end
              #factorLevelsForSampleDescriptors[sampleDescriptors[idx]] << currentFactorLevel 
            #}
          #end
        #}
        # Eliminate duplicate factor level terms for each sample identifier
        #factorLevelsForSampleDescriptors.each_key { |currentSampleIdentifier|
          #factorLevelsForSampleDescriptors[currentSampleIdentifier].uniq!
        #}
        #wbJobEntity.settings['factorLevelsForSampleDescriptors'] = factorLevelsForSampleDescriptors
        #wbJobEntity.settings['sampleDescriptors'] = sampleDescriptors
      #end
      # If we're OK so far, try to grab user's ERCC-related info and see whether the user has any remote storage areas in their database
      if(rulesSatisfied)
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Checking user's ERCC info.")
        # Check to see what PI the user is associated with
        submitterLogin = wbJobEntity.context['userLogin']
        apiCaller = ApiCaller.new(exRNAInternalKBHost, "/REST/v1/grp/{grp}/kb/{kb}/coll/{coll}/docs?matchProp={matchProp}&matchValues={matchVal}&matchMode=exact&detailed=true", user, pass)
        apiCaller.initInternalRequest(@rackEnv, genbConf.machineNameAlias) if(@rackEnv)
        apiCaller.get({:grp => exRNAInternalKBGroup, :kb => exRNAInternalKBName, :coll => exRNAInternalKBPICodesColl, :matchProp => submitterPropPath, :matchVal => submitterLogin})
        apiCaller.parseRespBody()
        if(!apiCaller.succeeded? and apiCaller.apiStatusObj["statusCode"] != "Forbidden")
          $stderr.debugPuts(__FILE__, __method__, "ERROR", "API caller resp body for failed call to PI KB: #{apiCaller.respBody}")
          wbJobEntity.context['wbErrorMsg'] = "API call failed when trying to grab PI associated with current user. Please try again. If you continue to experience issues, contact Sai (sailakss@bcm.edu) or William (thistlew@bcm.edu)."
          rulesSatisfied = false
        else
          # Set up arrays to store grant numbers and anticipated data repository options
          wbJobEntity.settings['grantNumbers'] = []
          wbJobEntity.settings['anticipatedDataRepos'] = []
          # If we can't find user (or we are unable to search the KB because we're not a member), then he/she is not registered as an ERCC user. We will prompt the user to contact Sai if he/she IS an ERCC user
          if(apiCaller.apiDataObj.size == 0 or apiCaller.apiStatusObj["statusCode"] == "Forbidden")
            wbJobEntity.settings['piName'] = "Non-ERCC PI"
            wbJobEntity.settings['grantNumbers'] << "Non-ERCC Funded Study"
            # Currently, if user is not a member of ERCC, his/her anticipated data repository is "None". This might not make sense, though (what if user is submitting data to dbGaP but isn't ERCC?)
            wbJobEntity.settings['anticipatedDataRepos'] << "None"
          # If user is associated with more than 1 PI, a mistake has occurred and we need to fix it.
          elsif(apiCaller.apiDataObj.size > 1)
            wbJobEntity.context['wbErrorMsg'] = "You are listed as being a submitter under two or more PIs. This is not allowed. Please contact Sai (sailakss@bcm.edu) or William (thistlew@bcm.edu) to fix this issue."
            rulesSatisfied = false
          else
            # If user is associated with only one PI, then we get that PI's information and save it (PI name, organization, grant numbers and associated grant tags)
            piDoc = BRL::Genboree::KB::KbDoc.new(apiCaller.apiDataObj[0])
            # PI ID 
            piID = piDoc.getPropVal("ERCC PI Code")
            wbJobEntity.settings['piID'] = piID
            # PI Name
            firstName = piDoc.getPropVal("ERCC PI Code.PI First Name")
            middleName = piDoc.getPropVal("ERCC PI Code.PI Middle Name") if(piDoc.getPropVal("ERCC PI Code.PI Middle Name"))
            lastName = piDoc.getPropVal("ERCC PI Code.PI Last Name")
            piName = firstName
            piName << " #{middleName}" if(middleName)
            piName << " #{lastName}"
            wbJobEntity.settings['piName'] = piName
            # Grab grant numbers (with associated grant tag)
            grantDetails = piDoc.getPropItems("ERCC PI Code.Grant Details")
            grantDetails.each { |currentGrant|
              currentGrant = BRL::Genboree::KB::KbDoc.new(currentGrant)
              grantNumber = currentGrant.getPropVal("Grant Number")
              grantTag = currentGrant.getPropVal("Grant Number.Grant Tag")
              wbJobEntity.settings['grantNumbers'] << "#{grantNumber} (#{grantTag})"
            }
            # Make sure we add "Non-ERCC Funded Study" to grant numbers list in case ERCC user wants to submit a non-ERCC study  
            wbJobEntity.settings['grantNumbers'] << "Non-ERCC Funded Study"
            # Different options available for anticipated data repository for ERCC users
            wbJobEntity.settings['anticipatedDataRepos'] = ["GEO", "dbGaP", "Both GEO & dbGaP", "None", "Other"]
          end
        end
        # Save user's remote storage areas in remoteStorageAreas array
        remoteStorageAreas = []
        output = @dbApiHelper.extractPureUri(outputs[0])
        uri = URI.parse(output)
        host = uri.host
        rcscUri = uri.path
        rcscUri = rcscUri.chomp("?")
        rcscUri << "/files?depth=immediate"
        apiCaller = ApiCaller.new(host, rcscUri, @hostAuthMap)
        apiCaller.initInternalRequest(@rackEnv, genbConf.machineNameAlias) if(@rackEnv)
        apiCaller.get()
        apiCaller.parseRespBody()
        listOfFiles = apiCaller.apiDataObj
        listOfFiles.each { |currentFile|
          nameOfFile = currentFile["name"].chomp("/")
          storageType = currentFile["storageType"]
          remoteStorageAreas << nameOfFile if(storageType != "local")
        }
        wbJobEntity.settings['remoteStorageAreas'] = remoteStorageAreas
      end
      if(rulesSatisfied and sectionsToSatisfy.include?(:settings))
        if(wbJobEntity.settings['analysisName'].empty? or wbJobEntity.settings['factorName1'].empty? or wbJobEntity.settings['factorLevel1'].empty? or wbJobEntity.settings['factorLevel2'].empty?)
          errorMsgArr.push("BLANK ANALYSIS NAME: You cannot leave your analysis name blank. Please fill in a value and try again.") if(wbJobEntity.settings['analysisName'].empty?)
          errorMsgArr.push("BLANK FACTOR NAME: You cannot leave your factor name blank. Please fill in a value and try again.") if(wbJobEntity.settings['factorName1'].empty?)
          errorMsgArr.push("BLANK FACTOR LEVEL: You cannot leave either factor level blank. Please fill in both values and try again.") if(wbJobEntity.settings['factorLevel1'].empty? or wbJobEntity.settings['factorLevel2'].empty?)
          rulesSatisfied = false
        end
      end
      # If rules are not satisfied, then fill out error message with all the files that were invalid
      unless(rulesSatisfied)
        wbJobEntity.context['wbErrorMsg'] = errorMsgArr
      end
      return rulesSatisfied
    end

    # Check file size
    def checkFileSize(errorMsgArr, fileName)
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Checking file size for file #{fileName}")
      ## Check if file is not empty
      fileSizeSatisfied = true
      fileUriObj = URI.parse(fileName)
      apiCaller = ApiCaller.new(fileUriObj.host, "#{fileUriObj.path}/size?", @hostAuthMap)
      apiCaller.initInternalRequest(@rackEnv, genbConf.machineNameAlias) if(@rackEnv)
      apiCaller.get()
      fileSize = JSON.parse(apiCaller.respBody)['data']['number'].to_i
      if(fileSize == 0)
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "File #{fileName} is empty. Rejecting job.")
        errorMsgArr.push("INVALID FILE SIZE: Input file #{File.basename(fileName).inspect} is currently empty, which is not allowed. If it was recently created, it may still be in the process of being transferred to Genboree storage, in which case please try the tool again in a few minutes.")
        fileSizeSatisfied = false # File is empty. Reject job immediately.
      elsif(fileSize > 1000000)
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "File #{fileName} is too large for web parsing (over 1000000 bytes). Will skip parsing step in RulesHelper.")
        @flagForWebServerParsing = true # File is too large to be parsed by web server. Will skip parsing step in RulesHelper.
      end   
      return fileSizeSatisfied
    end

    # Sniffer for ASCII / .tgz
    def sniffFileFormat(errorMsgArr, fileName, asciiFiles, coreResultFiles)
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Checking file type for file #{fileName}")
      fileUriObj = URI.parse(fileName)
      apiCaller = ApiCaller.new(fileUriObj.host, "#{fileUriObj.path}/sniffedType?", @hostAuthMap)
      apiCaller.initInternalRequest(@rackEnv, genbConf.machineNameAlias) if(@rackEnv)
      apiCaller.get()
      sniffedType = JSON.parse(apiCaller.respBody)['data']['text']
      if(sniffedType != 'ascii' and sniffedType != 'bedGraph' and sniffedType != 'gz')
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "File type for #{fileName} is neither ASCII nor .tgz format (is #{sniffedType}). Rejecting job.")
        errorMsgArr.push("INVALID FILE FORMAT: Input file #{fileName} is neither ASCII text format nor .tgz format (is #{sniffedType}). Please check the file format.")
      else
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "File type for #{fileName} is ASCII or gz.")
        @flagForWebServerParsing = true if(sniffedType == 'gz')
        if(sniffedType == 'gz' and !File.basename(fileName).include?("_CORE_RESULTS"))
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "File type for #{fileName} is gz, but the file doesn't look like a CORE_RESULTS archive file (at least by name). It's possible that user renamed CORE_RESULTS archive, but why? Rejecting job.")
          errorMsgArr.push("INVALID FILE: Input file #{fileName} is in .gz format, but its name doesn't include the CORE_RESULTS identifier for exceRpt core result archives. Did you rename your CORE_RESULTS archive, or submit a different .gz file? Please submit CORE_RESULTS archives generated directly by exceRpt.") 
        else 
          asciiFiles << File.basename(fileName) if(sniffedType == 'ascii' or sniffedType == 'bedGraph')
          coreResultFiles << File.basename(fileName) if(sniffedType == 'gz')
        end
      end
      return
    end
  end

end ; end; end # module BRL ; module Genboree ; module Tools
