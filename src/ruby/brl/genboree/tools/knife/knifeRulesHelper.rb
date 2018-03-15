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
  class KnifeRulesHelper < WorkbenchRulesHelper
    TOOL_ID = 'knife'
    
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
      # Apply basic rules from the rules file (counts, basic types, other simple things)
      rulesSatisfied = super(wbJobEntity, sectionsToSatisfy, toolIdStr)
      # If we pass that initial check, we need to make sure that all of our files are ASCII or archived files (and non-empty)
      errorMsgArr = []
      outputs = wbJobEntity.outputs
      if(rulesSatisfied)
        # Grab inputs
        fileList = @fileApiHelper.expandFileContainers(wbJobEntity.inputs, @userId)
        wbJobEntity.inputs = fileList
        inputs = wbJobEntity.inputs
        # ---------------------------------------------------------------------------------------
        # Check 1: Make sure the genome version is currently supported by KNIFE
        # ---------------------------------------------------------------------------------------
        genomesSatisfied = true
        targetDbUriObj = URI.parse(outputs[0])
        apiCaller = ApiCaller.new(targetDbUriObj.host, "#{targetDbUriObj.path}?", @hostAuthMap)
        apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
        apiCaller.get()
        resp = JSON.parse(apiCaller.respBody)['data']
        genomeVersion = resp['version'].decapitalize
        wbJobEntity.settings['genomeVersion'] = genomeVersion
        gbKNIFEGenomesInfo = JSON.parse(File.read(@genbConf.gbKNIFEGenomesInfo))
        unless(gbKNIFEGenomesInfo.key?(genomeVersion))
          wbJobEntity.context['wbErrorMsg'] = "INVALID GENOME: The genome assembly version: #{genomeVersion} is not currently supported by KNIFE. Supported genomes include: #{gbKNIFEGenomesInfo.keys.join(',')}. Please contact the Genboree administrator (sailakss@bcm.edu) for adding support for this genome."
          genomesSatisfied = false
          rulesSatisfied = false
        end

        if(genomesSatisfied)  # If genome is not supported, then do not process any further
          # If user submits empty folder / entity list, then provide error message
          if(inputs.size < 1)
            wbJobEntity.context['wbErrorMsg'] = "INVALID NUMBER OF INPUTS: If you submit a folder/entity list, you must give at least 1 input FASTQ file (no empty folders!)."
            rulesSatisfied = false
          # ------------------------------------------------------------------
          # Check 2: Are all the input files (including those inside entity lists or folders) 
          # from the same db version?
          # ------------------------------------------------------------------
          # If number of files is correct but files are from different db versions, we reject the job
          elsif(!checkDbVersions(inputs + outputs, skipNonDbUris=true))
            wbJobEntity.context['wbErrorMsg'] =
              {
                :msg => 'Some files are from a different genome assembly version than other files, or from the output database.',
                :type => :versions,
                :info =>
                {
                  :inputs =>  @trkApiHelper.dbVersionsHash(inputs),
                  :outputs => @dbApiHelper.dbVersionsHash(outputs)
                }
              }
            rulesSatisfied = false
          else
            # ------------------------------------------------------------------
            # Check 3: Make sure the right combination of inputs has been selected
            # ------------------------------------------------------------------
            # We need to check each input to make sure that it's non-empty and FASTQ (or compressed)
            fileSizeSatisfied = true
            fileFormatSatisfied = true
            inputs.each { |file|
              fileSizeSatisfied = checkFileSize(file)
              if(fileSizeSatisfied)
                fileFormatSatisfied = sniffFastqFormat(file)
                unless(fileFormatSatisfied)
                  errorMsgArr.push("INVALID_FILE_FORMAT: Input file #{file} is not in FASTQ format. This is only allowed if the file is compressed. Please check the file format.")
                  rulesSatisfied = false
                end
              else
                errorMsgArr.push("INVALID_FILE_SIZE: Input file #{file} is empty.  You cannot submit an empty file for processing.")
                rulesSatisfied = false
              end
            }
            unless(rulesSatisfied)
              wbJobEntity.context['wbErrorMsg'] = errorMsgArr
            end # unless(rulesSatisfied)
          end # 
        end # if(genomesSatisfied)

        # ------------------------------------------------------------------
        # CHECK SETTINGS
        # ------------------------------------------------------------------
        if(sectionsToSatisfy.include?(:settings))
          # Check :settings together with info from :outputs :
          unless( sectionsToSatisfy.include?(:outputs) and  sectionsToSatisfy.include?(:inputs) )
            raise ArgumentError, "Cannot validate just :settings for this tool without info provided in both :inputs and :outputs."
          end

          rulesSatisfied = false

          # Check1: A job with the same analysis name under the same target db should not exist
          output = @dbApiHelper.extractPureUri(outputs[0])
          uri = URI.parse(output)
          host = uri.host
          rcscUri = uri.path
          rcscUri = rcscUri.chomp("?")
          @toolVersion = @toolConf.getSetting('info', 'version')
          rcscUri << "/file/exceRptPipeline_v#{@toolVersion}/#{CGI.escape(wbJobEntity.settings['analysisName'])}/jobFile.json?"
          apiCaller = ApiCaller.new(host, rcscUri, @hostAuthMap)
          apiCaller.initInternalRequest(@rackEnv, genbConf.machineNameAlias) if(@rackEnv)
          apiCaller.get()
          if(apiCaller.succeeded?) # Failed: job dir already exists
            wbJobEntity.context['wbErrorMsg'] = "A job with the analysis name #{wbJobEntity.settings['analysisName']} has already been launched before. Please select a different analysis name."
          else
            settings =  wbJobEntity.settings
            # Check 2: Ensure manual adapter sequence (if it's being used) has only ATGCN characters
            adapterSequenceOption = settings['adapterSequence']
            autoDetectOption = settings['autoDetectAdapter']
            manualAdapterSequence = settings['manualAdapter']
            if(adapterSequenceOption == "z_other" and autoDetectOption == "b_no" and manualAdapterSequence !~ /^[ATGCNatgcn]+$/)
              wbJobEntity.context['wbErrorMsg'] = "Manual adapter sequence is empty or contains characters other than [ATGCN]. Please check your manual adapter sequence and try again."
              rulesSatisfied = false
            else
              rulesSatisfied = true
            end
          end # if(apiCaller.succeeded?)
        end # if(sectionsToSatisfy.include?(:settings))
      end # if(rulesSatisfied)
      # If we're OK so far, try to grab user's ERCC-related info and see whether the user has any remote storage areas in their database
      if(rulesSatisfied)
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
      return rulesSatisfied
    end

    # Check file size
    def checkFileSize(fileName)
      ## Check if file is not empty
      fileSizeSatisfied = true
      fileUriObj = URI.parse(fileName)
      apiCaller = ApiCaller.new(fileUriObj.host, "#{fileUriObj.path}/size?", @hostAuthMap)
      apiCaller.initInternalRequest(@rackEnv, genbConf.machineNameAlias) if(@rackEnv)
      apiCaller.get()
      fileSize = JSON.parse(apiCaller.respBody)['data']['number'].to_i
      if(fileSize == 0)
        fileSizeSatisfied = false # File is empty. Reject job immediately.
      end 
      return fileSizeSatisfied
    end

    # Sniffer for FASTQ/SRA
    def sniffFastqFormat(fileName)
      fileFormatSatisfied = true
      fileUriObj = URI.parse(fileName)
      apiCaller = ApiCaller.new(fileUriObj.host, "#{fileUriObj.path}/compressionType?", @hostAuthMap)
      apiCaller.initInternalRequest(@rackEnv, genbConf.machineNameAlias) if(@rackEnv)
      apiCaller.get()
      type = JSON.parse(apiCaller.respBody)['data']['text']
      if(type != 'text')
        fileFormatSatisfied = true # File is compressed (not text), so assume format is true and check if file is FASTQ in the wrapper
      else
      # To check FASTQ format if file is not compressed and not empty
        fileUriObj = URI.parse(fileName)
        apiCaller = ApiCaller.new(fileUriObj.host, "#{fileUriObj.path}/sniffedType?", @hostAuthMap)
        apiCaller.initInternalRequest(@rackEnv, genbConf.machineNameAlias) if(@rackEnv)
        apiCaller.get()
        sniffedType = JSON.parse(apiCaller.respBody)['data']['text']
        if(sniffedType != 'fastq')
          fileFormatSatisfied = false # Since file is not FASTQ, return false
        end
      end
      return fileFormatSatisfied
    end
  end

end ; end; end # module BRL ; module Genboree ; module Tools
