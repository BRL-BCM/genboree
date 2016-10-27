require 'brl/genboree/tools/workbenchRulesHelper'
require 'brl/genboree/tools/workbenchFormHelper'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require 'brl/genboree/rest/helpers/fileApiUriHelper'
require 'uri'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/rest/apiCaller'
require 'brl/genboree/helpers/sniffer'
include BRL::Genboree::REST

module BRL ; module Genboree ; module Tools
  class PathwayFinderRulesHelper < WorkbenchRulesHelper
    TOOL_ID = 'pathwayFinder'
    
    def rulesSatisfied?(wbJobEntity, sectionsToSatisfy=[ :inputs, :outputs, :context, :settings ], toolIdStr=@toolIdStr)
      # Grab necessary variables for grabbing submitter's ERCC info (used for tool usage doc)
      @exRNAInternalKBHost = @genbConf.exRNAInternalKBHost
      wbJobEntity.settings['exRNAInternalKBHost'] = @exRNAInternalKBHost
      @exRNAInternalKBGroup = @genbConf.exRNAInternalKBGroup
      wbJobEntity.settings['exRNAInternalKBGroup'] = @exRNAInternalKBGroup
      @exRNAInternalKBName = @genbConf.exRNAInternalKBName
      wbJobEntity.settings['exRNAInternalKBName'] = @exRNAInternalKBName
      @exRNAInternalKBPICodesColl = @genbConf.exRNAInternalKBPICodesColl
      wbJobEntity.settings['exRNAInternalKBPICodesColl'] = @exRNAInternalKBPICodesColl
      @submitterPropPath = "ERCC PI Code.Submitters.Submitter ID.Submitter Login"
      # We also save tool usage collection name for filling out tool usage doc later on
      @exRNAInternalKBToolUsageColl = @genbConf.exRNAInternalKBToolUsageColl
      wbJobEntity.settings['exRNAInternalKBToolUsageColl'] = @exRNAInternalKBToolUsageColl
      # Grab dbrc info for making API call to PI Codes collection
      user = @superuserApiDbrc.user
      pass = @superuserApiDbrc.password
      # Save error messages about individual files in errorMsgArr
      errorMsgArr = []
      # Apply basic rules from the rules file (counts, basic types, other simple things)
      rulesSatisfied = super(wbJobEntity, sectionsToSatisfy, toolIdStr)
      # If we pass that initial check, we need to make sure that all of our files are ASCII or archived files (and non-empty)
      if(rulesSatisfied)
        # Grab inputs
        fileList = @fileApiHelper.expandFileContainers(wbJobEntity.inputs, @userId)
        wbJobEntity.inputs = fileList
        inputs = wbJobEntity.inputs
        # This tool currently only accepts one input .txt file at a time, so we need to reject the job if the user tried to submit multiple input files
        # This problem is partially handled by workbench.rules.json, but it's possible to get past that restriction (for example, by submitting a folder that contains two input files)
        if(inputs.size() > 1)
          errorMsgArr.push("INVALID_NUMBER_OF_INPUTS: You have submitted more than one input file for processing. Please submit only one file for processing at a time.")
          rulesSatisfied = false
        else
          # We need to check each input to make sure that it's non-empty and text (or compressed)
          fileSizeSatisfied = ""
          fileFormatSatisfied = true
          inputs.each { |file|
            fileSizeSatisfied = checkFileSize(file)
            if(fileSizeSatisfied.empty?)
              fileFormatSatisfied = sniffASCIIFormat(file)
              unless(fileFormatSatisfied)
                errorMsgArr.push("INVALID_FILE_FORMAT: Input file #{file} is not in ASCII text format. This is required - please check the file format.")
                rulesSatisfied = false
              end
            else
              if(fileSizeSatisfied == "empty")
                errorMsgArr.push("INVALID_FILE_SIZE: Input file #{file} is empty. You cannot submit an empty file for processing.")
              elsif(fileSizeSatisfied == "too big")
                errorMsgArr.push("INVALID_FILE_SIZE: Input file #{file} is too large for processing (over 5000000 bytes). Reduce your file size and then try again.")
              end
              rulesSatisfied = false
            end
          }
        end
      end
      # If rules are not satisfied, then fill out error message with all the files that were invalid
      unless(rulesSatisfied)
        wbJobEntity.context['wbErrorMsg'] = errorMsgArr
      else
        # If we're OK so far, we'll try to grab user's ERCC-related info
        # Check to see what PI the user is associated with
        submitterLogin = wbJobEntity.context['userLogin']
        apiCaller = ApiCaller.new(@exRNAInternalKBHost, "/REST/v1/grp/{grp}/kb/{kb}/coll/{coll}/docs?matchProp={matchProp}&matchValues={matchVal}&matchMode=exact&detailed=true", user, pass)
        apiCaller.initInternalRequest(@rackEnv, genbConf.machineNameAlias) if(@rackEnv)
        apiCaller.get({:grp => @exRNAInternalKBGroup, :kb => @exRNAInternalKBName, :coll => @exRNAInternalKBPICodesColl, :matchProp => @submitterPropPath, :matchVal => submitterLogin})
        if(!apiCaller.succeeded? and apiCaller.parseRespBody["status"]["statusCode"] != "Forbidden")
          $stderr.debugPuts(__FILE__, __method__, "ERROR", "API caller resp body for failed call to PI KB: #{apiCaller.respBody}")
          wbJobEntity.context['wbErrorMsg'] = "API call failed when trying to grab PI associated with current user. Please try again. If you continue to experience issues, contact Sai (sailakss@bcm.edu)."
          rulesSatisfied = false
        else
          # Set up arrays to store grant numbers and anticipated data repository options
          wbJobEntity.settings['grantNumbers'] = []
          wbJobEntity.settings['anticipatedDataRepos'] = []
          # If we can't find user (or we are unable to search the KB because we're not a member), then he/she is not registered as an ERCC user. We will prompt the user to contact Sai if he/she IS an ERCC user
          if(apiCaller.parseRespBody["data"].size == 0 or apiCaller.parseRespBody["status"]["statusCode"] == "Forbidden")
            wbJobEntity.settings['piName'] = "Non-ERCC PI"
            wbJobEntity.settings['grantNumbers'] << "Non-ERCC Funded Study"
            # Currently, if user is not a member of ERCC, his/her anticipated data repository is "None". This might not make sense, though (what if user is submitting data to dbGaP but isn't ERCC?)
            wbJobEntity.settings['anticipatedDataRepos'] << "None"
          # If user is associated with more than 1 PI, a mistake has occurred and we need to fix it.
          elsif(apiCaller.parseRespBody["data"].size > 1)
            wbJobEntity.context['wbErrorMsg'] = "You are listed as being a submitter under two or more PIs. This is not allowed. Please contact Sai (sailakss@bcm.edu) to fix this issue."
            rulesSatisfied = false
          else
            # If user is associated with only one PI, then we get that PI's information and save it (PI name, organization, grant numbers and associated grant tags)
            piDoc = BRL::Genboree::KB::KbDoc.new(apiCaller.parseRespBody["data"][0])
            # PI ID 
            piID = piDoc.getPropVal("ERCC PI Code")
            wbJobEntity.settings['piID'] = piID
            # PI Name
            firstName = piDoc.getPropVal("ERCC PI Code.PI First Name")
            middleName = piDoc.getPropVal("ERCC PI Code.PI Middle Name") if(piDoc.getPropVal("ERCC PI Code.PI Middle Name"))
            lastName = piDoc.getPropVal("ERCC PI Code.PI Last Name")
            piName = "#{firstName}"
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
      end
      return rulesSatisfied
    end

    # Check file size
    def checkFileSize(fileName)
      ## Check if file is not empty
      fileSizeSatisfied = ""
      fileUriObj = URI.parse(fileName)
      apiCaller = ApiCaller.new(fileUriObj.host, "#{fileUriObj.path}/size?", @hostAuthMap)
      apiCaller.initInternalRequest(@rackEnv, genbConf.machineNameAlias) if(@rackEnv)
      apiCaller.get()
      fileSize = JSON.parse(apiCaller.respBody)['data']['number'].to_i
      if(fileSize == 0)
        fileSizeSatisfied = "empty" # File is empty. Reject job immediately.
      elsif(fileSize > 5000000)
        fileSizeSatisfied = "too big" # File is over 5 megs in size. Reject job immediately.
      end
      return fileSizeSatisfied
    end

    # Sniffer for ASCII
    def sniffASCIIFormat(fileName)
      fileFormatSatisfied = true
      fileUriObj = URI.parse(fileName)
      apiCaller = ApiCaller.new(fileUriObj.host, "#{fileUriObj.path}/sniffedType?", @hostAuthMap)
      apiCaller.initInternalRequest(@rackEnv, genbConf.machineNameAlias) if(@rackEnv)
      apiCaller.get()
      sniffedType = JSON.parse(apiCaller.respBody)['data']['text']
      if(sniffedType != 'ascii')
        fileFormatSatisfied = false # Since file is not ASCII, return false
      end
      return fileFormatSatisfied
    end
  end

end ; end; end # module BRL ; module Genboree ; module Tools
