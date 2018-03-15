require 'brl/genboree/tools/workbenchRulesHelper'
require 'brl/genboree/tools/workbenchFormHelper'
require 'brl/genboree/rest/helpers/trackApiUriHelper'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require 'brl/genboree/rest/helpers/fileApiUriHelper'
require 'uri'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/rest/apiCaller'
require 'brl/genboree/helpers/sniffer'
include BRL::Genboree::REST

module BRL ; module Genboree ; module Tools
  class ExceRptPipelineRulesHelper < WorkbenchRulesHelper
    
    TOOL_ID = 'exceRptPipeline'
    
    def rulesSatisfied?(wbJobEntity, sectionsToSatisfy=[ :inputs, :outputs, :context, :settings ], toolIdStr=@toolIdStr)
      # Grab necessary variables for grabbing submitter's ERCC info (used for tool usage doc)
      exRNAInternalKBHost = @genbConf.exRNAInternalKBHost
      exRNAInternalKBGroup = @genbConf.exRNAInternalKBGroup
      exRNAInternalKBName = @genbConf.exRNAInternalKBName
      exRNAInternalKBPICodesColl = @genbConf.exRNAInternalKBPICodesColl
      submitterPropPath = "ERCC PI Code.Submitters.Submitter ID.Submitter Login"
      # Grab dbrc info for making API call to PI Codes collection
      user = @superuserApiDbrc.user
      pass = @superuserApiDbrc.password
      # Apply basic rules from the rules file (counts, basic types, other simple things)
      errorMsgArr = []
      rulesSatisfied = super(wbJobEntity, sectionsToSatisfy, toolIdStr)
      # Must pass the rest of the checks as well
      if(rulesSatisfied)
        # Grab inputs and outputs, and set @totalInputFileSize, measure of the total size of inputs, to 0
        inputs = wbJobEntity.inputs
        outputs = wbJobEntity.outputs
        @totalInputFileSize = 0
        # Grab version of output database - we'll make that our default selected genome for the user if it makes sense
        targetDbUriObj = URI.parse(outputs[0])
        apiCaller = ApiCaller.new(targetDbUriObj.host, "#{targetDbUriObj.path}?", @hostAuthMap)
        apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
        apiCaller.get()
        resp = JSON.parse(apiCaller.respBody)['data']
        genomeVersion = resp['version'].decapitalize
        wbJobEntity.settings['databaseGenomeVersion'] = genomeVersion
        # ------------------------------------------------------------------
        # Check Inputs/Outputs
        # ------------------------------------------------------------------
        fileList = @fileApiHelper.expandFileContainers(wbJobEntity.inputs, @userId)
        wbJobEntity.inputs = fileList
        inputs = wbJobEntity.inputs
        # If user submits empty folder / entity list, then provide error message
        if(inputs.size < 1)
          wbJobEntity.context['wbErrorMsg'] = "INVALID NUMBER OF INPUTS: If you submit a folder/entity list, you must give at least 1 input FASTQ/SRA file (no empty folders!)."
          rulesSatisfied = false
        else
          # ------------------------------------------------------------------
          # Check: Make sure the right combination of inputs has been selected
          # ------------------------------------------------------------------
          fileSizeSatisfied = true
          fileFormatSatisfied = true
          inputs.each { |file|
            fileSizeSatisfied = checkFileSize(file)
            if(fileSizeSatisfied)
              fileFormatSatisfied = sniffCompressedFormat(file)
              unless(fileFormatSatisfied)
                errorMsgArr.push("INVALID_FILE_FORMAT: Input file #{file} is not compressed. We no longer allow raw FASTQ/SRA inputs (they take up too much space). Please compress your inputs and try again. To compress your inputs on Genboree, you can use the Prepare Archive tool, which is found under Data -> Files in the tool menu.")
                rulesSatisfied = false
              end
            else
              errorMsgArr.push("INVALID_FILE_SIZE: Input file #{file} is empty. You cannot submit an empty file for processing.")
              rulesSatisfied = false
            end
          }
          unless(rulesSatisfied)
            wbJobEntity.context['wbErrorMsg'] = errorMsgArr
          end # unless(rulesSatisfied)
        end # 

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
          toolVersion = @toolConf.getSetting('info', 'version')
          if(wbJobEntity.settings['exceRptGen'] == 'thirdGen')
            toolVersion = "3.3.0"
          end
          rcscUri << "/file/exceRptPipeline_v#{toolVersion}/#{CGI.escape(wbJobEntity.settings['analysisName'])}/jobFile.json?"
          apiCaller = ApiCaller.new(host, rcscUri, @hostAuthMap)
          apiCaller.initInternalRequest(@rackEnv, genbConf.machineNameAlias) if(@rackEnv)
          apiCaller.get()
          if(apiCaller.succeeded?) # Failed: job dir already exists
            wbJobEntity.context['wbErrorMsg'] = "A job with the analysis name #{wbJobEntity.settings['analysisName']} has already been launched before. Please select a different analysis name."
          else
            # Check 2: Ensure manual adapter sequence (if it's being used) has only ATGCN characters
            if(wbJobEntity.settings['adapterSequence'] == "y_manual" and wbJobEntity.settings['manualAdapter'] !~ /^[ATGCNatgcn]+$/)
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
      # TEMPORARY: WE ARE SETTING A LIMIT OF 5 GB ON THE TOTAL FILE SIZE (BECAUSE OF WEIRD MEMORY LEAK PROBLEM)
      if(rulesSatisfied)
        if(@totalInputFileSize > 10000000000)
          wbJobEntity.context['wbErrorMsg'] = "TEMPORARY: There is a temporary file size limit of 10 GB for any given exceRpt job. Please resubmit your job with smaller files and try again."
          rulesSatisfied = false
        end
      end
      # If rules are still satisfied, let's check how much storage space the user is taking up in his/her Group.
      # If we predict that the user is going to exceed the Group's limit, we will reject the job.
      # Note that we only do this if the user selected the option to upload the full results (alignment files)
      if(rulesSatisfied and sectionsToSatisfy.include?(:settings) and (wbJobEntity.settings['uploadFullResults'] or (wbJobEntity.settings['uploadExogenousAlignments'] and wbJobEntity.settings['exogenousMapping'] == "c_on")))
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "User chose to upload full results, so we'll check the output Group's disk usage")
        # First, are we checking remote storage space, or local space?
        # If user selected a remote storage area, then we will check remote storage space - otherwise, we'll check local space.
        checkRemoteStorage = false
        if(wbJobEntity.settings['remoteStorageArea'] and wbJobEntity.settings['remoteStorageArea'] != "None Selected")
          checkRemoteStorage = true
        end
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "User is uploading to remote storage? #{checkRemoteStorage}")
        # Create dbu object for finding out disk usage info
        dbuForCheckingDiskUsage = BRL::Genboree::DBUtil.new(@genbConf.dbrcKey, nil, nil) 
        # Grab Genboree Group / Genboree DB
        output = @dbApiHelper.extractPureUri(outputs[0])
        groupName = @grpApiHelper.extractName(output)
        dbName = @dbApiHelper.extractName(output)
        # Set up dbu object to point at correct Genboree Group / Database
        databaseMySQLName = dbuForCheckingDiskUsage.selectRefseqByNameAndGroupName(dbName, groupName)[0]["databaseName"]
        dbuForCheckingDiskUsage.setNewDataDb(databaseMySQLName)
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Created dbUtil object to check current disk space usage for Group")
        # Create storage helper (local or FTP) to help us check disk space usage
        if(checkRemoteStorage)
          storageHelper = createStorageHelperFromTopRec(wbJobEntity.settings['remoteStorageArea'], groupName, dbName, @userId, dbuForCheckingDiskUsage)
        else
          storageHelper = createStorageHelperFromTopRec("", groupName, dbName, @userId, dbuForCheckingDiskUsage)
        end
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Created storage helper: #{storageHelper.class}")
        # Check storage space taken up by group on local or remote space
        totalSpaceConsumed = storageHelper.checkDiskSpaceForGroup()
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Total current disk space usage (grabbed by storage helper): #{totalSpaceConsumed}")
        # We'll keep adding to this variable below for total space consumed, but let's also save the total right now in a nice (GB) format for user readability
        # This number will be the amount of space consumed by existing data in the Group
        gbyteSpaceConsumedByExistingFiles = "#{(totalSpaceConsumed * 100 / 1000000000.0).round / 100.0} GB"
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Total disk space usage converted to GB: #{gbyteSpaceConsumedByExistingFiles}")
        # Check total amount of storage space permitted (info is in exceRpt's tool conf)
        # If group isn't in tool conf, then we assume default (for now, 100 GB local and 100 GB remote)
        totalSpaceAllowed = @toolConf.getSetting('groupDiskSpace', groupName) rescue nil
        unless(checkRemoteStorage)
          typeOfStorage = "local"
          switchingStorage = "remote instead of local"
          totalSpaceAllowed = totalSpaceAllowed ? totalSpaceAllowed["local"] : "100 GB"
        else
          typeOfStorage = "remote"
          switchingStorage = "local instead of remote"
          totalSpaceAllowed = totalSpaceAllowed ? totalSpaceAllowed["remote"] : "100 GB"
        end
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Total disk space usage permitted for Group in GB: #{totalSpaceAllowed}")
        # Formatting in tool conf is like "100 GB", so we cut off " GB" and then multiply to convert GB to bytes
        # We'll still keep around the GB version for displaying to user, though
        gbyteTotalSpaceAllowed = totalSpaceAllowed.clone()
        totalSpaceAllowed.gsub!(" GB", "")
        totalSpaceAllowed = totalSpaceAllowed.to_i * 1000000000
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Total disk space usage permitted: #{totalSpaceAllowed}")
        # Next, we want to estimate how much space the user will take up with his/her current submission
        # William calculated the following multipliers for different exogenousMapping settings for exceRpt results.
        # These are ROUGH estimates!
        multiplier = 1
        if(wbJobEntity.settings['uploadFullResults'])
          if(wbJobEntity.settings['exogenousMapping'] == "a_off")
            multiplier = @toolConf.getSetting('settings', 'compressedMultiplierExoOff').to_f
          elsif(wbJobEntity.settings['exogenousMapping'] == "b_miRNA")
            multiplier = @toolConf.getSetting('settings', 'compressedMultiplierExoMiRNA').to_f
          elsif(wbJobEntity.settings['exogenousMapping'] == "c_on")
            multiplier = @toolConf.getSetting('settings', 'compressedMultiplierExoOn').to_f
          end
        elsif(wbJobEntity.settings['uploadExogenousAlignments'] and wbJobEntity.settings['exogenousMapping'] == "c_on")
          multiplier = @toolConf.getSetting('settings', 'compressedMultiplierExoOnExoOnly').to_f
        end
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Exogenous multiplier (based on exogenous mapping setting chosen by user): #{multiplier}")
        # Multiply total input file size by multiplier (this is our predicted total output size for this job)
        totalOutputFileSizeCurrentJob = (@totalInputFileSize * multiplier).round
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Total input file size: #{@totalInputFileSize}")
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Total estimated output file size (using multiplier): #{totalOutputFileSizeCurrentJob}")
        # We'll save this in the job settings so that a later exceRpt job can easily find that information
        wbJobEntity.settings['totalOutputFileSize'] = totalOutputFileSizeCurrentJob
        # Convert total output size to GB format (rounded to 2 decimal places) for user readability
        gbyteTotalOutputFileSizeCurrentJob = "#{(totalOutputFileSizeCurrentJob * 100 / 1000000000.0).round / 100.0} GB"
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Total estimated output file size converted to GB: #{gbyteTotalOutputFileSizeCurrentJob}")
        # Add total output size to total space consumed
        totalSpaceConsumed += totalOutputFileSizeCurrentJob
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Total space consumed (current usage + estimated output size): #{totalSpaceConsumed}")
        # Finally, we need to check whether the user is currently running any jobs, and if so, how much space (roughly) those will take up.
        # Grab user's login name (used to find jobs)
        userLogin = wbJobEntity.context['userLogin']
        # Create DBUtil object and set its database to the prequeue database
        dbuForJobs = BRL::Genboree::DBUtil.new(@genbConf.dbrcKey, nil, nil)
        dbuForJobs.setNewOtherDb(@genbConf.prequeueDbrcKey)
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Created dbUtil object to check relevant jobs to gather more disk usage info")
        # We will filter our job ID search by user login, relevant tool IDs, and statuses that could indicate a running or waiting job
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Filtering jobs for #{userLogin} by tool IDs #{@toolConf.getSetting('settings', 'toolIdStrsForStorageSniffing').inspect} and statuses #{[:entered, :submitted, :running, :wait4deps].inspect}")
        filters = {"users" => userLogin, "toolIdStrs" => @toolConf.getSetting('settings', 'toolIdStrsForStorageSniffing'), "statuses" => [:entered, :submitted, :running, :wait4deps]}
        # Find the job IDs that meet the criteria above
        jobIdRecs = dbuForJobs.selectJobIdsByFilters(filters)
        # Grab the actual IDs from the generated hash
        jobIds = jobIdRecs.map { |jobRec| jobRec['id'] }
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Job IDs that meet above criteria: #{jobIds.inspect}")
        # Find the job records associated with the job IDs grabbed above - if no jobIds are grabbed from above, then we'll rescue the method with an empty array
        if(jobIds.size > 0)
          jobRecs = dbuForJobs.selectJobFullInfosByJobIds(jobIds, {}, filters)
        else
          jobRecs = []
        end
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Done searching for job confs associated with job IDs above")
        # totalOutputFileSizeOtherJobs will store the total amount of (estimated) space that will be taken up by currently running or entered jobs
        totalOutputFileSizeOtherJobs = 0
        # Traverse each job record
        jobRecs.each { |jobRec|
          # Grab the job status for the current job record
          status = jobRec['status']
          # We want to calculate the total amount of time elapsed since the current job was entered into the jobs table.
          # This calculation will differ depending on the particular job status.
          timeElapsed = nil
          withinTimeLimit = false
          if(status == 'entered' or status == 'wait4deps')
            timeElapsed = Time.now() - jobRec['entryDate']
            # Time limit of 1 month
            withinTimeLimit = true if(timeElapsed <= 2592000)
          elsif(status == 'submitted')
            timeElapsed = Time.now() - jobRec['submitDate']
            # Time limit of 1 month
            withinTimeLimit = true if(timeElapsed <= 2592000)
          elsif(status == 'running')
            timeElapsed = Time.now() - jobRec['execStartDate']
            wallTime = @toolConf.getSetting('cluster', 'walltime') rescue nil
            wallTime = wallTime.split(":")
            wallTime = wallTime[0].to_i * 3600 + wallTime[1].to_i * 60 + wallTime[2].to_i
            # Time limit of walltime
            withinTimeLimit = true if(timeElapsed <= wallTime)
          else
            timeElapsed = "N/A"
          end
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Job #{jobRec['name']} has a status of #{status}. The time elapsed is #{timeElapsed}. Is it within our time limit? #{withinTimeLimit}")
          #  First, job must be within the time limit for its job status (we don't want to consider really old jobs)
          if(withinTimeLimit)
            # Grab job settings from job record and check whether job is uploading to remote storage or not
            jobSettings = JSON.parse(jobRec['settings'])
            jobCheckRemoteStorage = false
            jobCheckRemoteStorage = true if(jobSettings['remoteStorageArea'] and jobSettings['remoteStorageArea'] != "None Selected")
            # Grab outputs from job record and check the associated group
            jobOutputs = JSON.parse(jobRec['output'])
            jobOutput = @dbApiHelper.extractPureUri(jobOutputs[0])
            jobGroupName = @grpApiHelper.extractName(jobOutput)
            # We will add the current job to our estimate of total space consumed by the user if the job passes the following checks:
            #  1. Job's group name must match the current submission's group name (Disk space is considered on a group-by-group basis)
            #  2. Job must be local if current submission is local, and remote (FTP-backed) if current submission is remote (FTP-backed) (we consider disk usage by local files and remote files separately)
            #  3. Job must include totalOutputFileSize in its settings (we need this number to figure out how much to add to our estimation of disk usage)
            $stderr.debugPuts(__FILE__, __method__, "STATUS", "Does this other job's Group name match the Group name for this job? #{jobGroupName == groupName}")
            $stderr.debugPuts(__FILE__, __method__, "STATUS", "Does this other job's storage type match the storage type name for this job? #{jobCheckRemoteStorage == checkRemoteStorage}")
            $stderr.debugPuts(__FILE__, __method__, "STATUS", "Does this other job contain info about total output file size for that job? #{!jobSettings['totalOutputFileSize'].nil?}")
            if(withinTimeLimit and jobGroupName == groupName and jobCheckRemoteStorage == checkRemoteStorage and jobSettings['totalOutputFileSize'])
              $stderr.debugPuts(__FILE__, __method__, "STATUS", "All criteria are met, so we'll add this other job's estimated output file size (#{jobSettings['totalOutputFileSize'].to_i}) to our total for other jobs (#{totalOutputFileSizeOtherJobs}) as well as our grand total estimation (#{totalSpaceConsumed})")
              totalOutputFileSizeOtherJobs += jobSettings['totalOutputFileSize'].to_i
              totalSpaceConsumed += jobSettings['totalOutputFileSize'].to_i
            end
          end
        }
        # Convert total output space consumed by other jobs to GB format (rounded to 2 decimal places) for user readability
        gbyteTotalOutputFileSizeOtherJobs = "#{(totalOutputFileSizeOtherJobs * 100 / 1000000000.0).round / 100.0} GB"
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Total amount of disk space estimated for other jobs converted to GB: #{gbyteTotalOutputFileSizeOtherJobs}")
        # Convert total space consumed to GB format (rounded to 2 decimal places) for user readability
        gbyteTotalSpaceConsumed = "#{(totalSpaceConsumed * 100 / 1000000000.0).round / 100.0} GB"
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Total amount of disk space estimated for grand total: #{gbyteTotalSpaceConsumed}")
        # We're not going to report any info about total output file size of other jobs if there are no relevant other jobs
        if(totalOutputFileSizeOtherJobs != 0)
          otherJobStr = ", and we estimate that the other jobs you have running will generate #{gbyteTotalOutputFileSizeOtherJobs}."    
        else
          otherJobStr = "."
        end
        # Temporary reporting of some stats found above (regardless of whether user hits storage max) - might be useful!
        $stderr.debugPuts(__FILE__, __method__, "DEBUG", "Type of storage: #{typeOfStorage} ; gbyteSpaceConsumedByExistingFiles: #{gbyteSpaceConsumedByExistingFiles} ; gbyteTotalOutputFileSizeCurrentJob: #{gbyteTotalOutputFileSizeCurrentJob} ; gbyteTotalOutputFileSizeOtherJobs: #{gbyteTotalOutputFileSizeOtherJobs} ; gbyteTotalSpaceConsumed: #{gbyteTotalSpaceConsumed} ; gbyteTotalSpaceAllowed: #{gbyteTotalSpaceAllowed}")
        # If user is exceeding total amount of space allowed, report error with all info gathered above. 
        if(totalSpaceConsumed > totalSpaceAllowed)
          wbJobEntity.context['wbErrorMsg'] = "You have run out of storage space on #{typeOfStorage} storage for your Group, so we are unable to submit your job with the 'Upload Full Results' option. You are currently using #{gbyteSpaceConsumedByExistingFiles} in your Group. We estimate that your submission will generate #{gbyteTotalOutputFileSizeCurrentJob}#{otherJobStr} Thus, we estimate that you will consume in total #{gbyteTotalSpaceConsumed} and you are only allowed to use #{gbyteTotalSpaceAllowed}. Please delete some files using the Delete File tool or switch to an alternative mode of storage (#{switchingStorage}). If you would like to discuss increasing your storage capacity with us, please contact Sai (sailakss@bcm.edu) or William (thistlew@bcm.edu)."
          rulesSatisfied = false
        end
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
      # Make sure we add fileSize to @totalInputFileSize
      @totalInputFileSize += fileSize
      if(fileSize == 0)
        fileSizeSatisfied = false # File is empty. Reject job immediately.
      end # 
      return fileSizeSatisfied
    end

    # Sniffer for compressed format
    def sniffCompressedFormat(fileName)
      fileFormatSatisfied = true
      fileUriObj = URI.parse(fileName)
      apiCaller = ApiCaller.new(fileUriObj.host, "#{fileUriObj.path}/compressionType?", @hostAuthMap)
      apiCaller.initInternalRequest(@rackEnv, genbConf.machineNameAlias) if(@rackEnv)
      apiCaller.get()
      type = JSON.parse(apiCaller.respBody)['data']['text']
      if(type != 'text')
        fileFormatSatisfied = true # File is compressed (not text), so assume format is true and check if file is FASTQ/SRA in the wrapper
      else
        fileFormatSatisfied = false # File is uncompressed, so we reject it (no raw FASTQ files allowed as input anymore!)
      end
      return fileFormatSatisfied
    end

    # It's a good idea to catch any potential errors now instead of relying on the job to do validation because,
    # the job may get queued and the user wouldn't be notified  for an unnecessarily long time that they have something minor wrong with their inputs.
    # [+returns+] boolean
    def warningsExist?(wbJobEntity)
      warningsExist = true
      if(wbJobEntity.context['warningsConfirmed'])
        # The user has confirmed the warnings and wants to proceed
        warningsExist = false
      else # Look for warnings
        # no warnings for now
        warningsExist = false
      end # if(wbJobEntity.context['warningsConfirmed']) 
        
      # Clean up helpers, which cache many things
      @trkApiHelper.clear() if(!@trkApiHelper.nil?)
      @dbApiHelper.clear() if(!@dbApiHelper.nil?)
      return warningsExist
    end # def warningsExist?(wbJobEntity)

    # This method creates a storage helper from a file name by looking at its top-level file record.
    # The top-level folder will either not exist (which means it's local) or it will exist (and can be local or remote).
    # A workbench tool will create this top-level folder when a user creates his/her remote area in his/her database.
    # This means that the to-level folder is a reliable way of checking whether the CURRENT file is going to be local or remote.
    # @param [String] fileName file name for current file 
    # @param [String] groupName group name associated with current file 
    # @param [String] dbName database name associated with current file
    # @param [Fixnum] userId current user's ID 
    # @param [BRL::Genboree::DBUtil] dbu used for finding file record info for current file
    # @param [boolean] muted indicates whether storage helper (and accompanying helpers) are muted or not - useful for deferrable bodies
    # @return [FtpStorageHelper or String] storage helper (or dummy string variable) based on top-level file record for current file
    def createStorageHelperFromTopRec(fileName, groupName, dbName, userId, dbu, muted=false)
      # isLocalFile will keep track of whether the file we're inserting is local or remote
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Checking whether file is local or remote.")
      isLocalFile = false
      # Grab file record associated with top-level folder - all remote files will have a top-level folder with the appropriate remoteStorageConf_id
      topFolderPath = "#{fileName.split("/")[0]}/"
      topFolderRecs = dbu.selectFileByDigest(topFolderPath, true)
      topStorageID = nil
      # If this top folder doesn't exist yet, then we should be dealing with a local file (since all remote files are required to have their top-level directory created by the workbench)
      if(topFolderRecs.nil? or topFolderRecs.empty?)
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "No top-level folder file record exists. File is local.")
        isLocalFile = true
      else
        # Grab remote storage ID associated with top-level folder
        topFolderRec = topFolderRecs[0]
        topStorageID = topFolderRec["remoteStorageConf_id"]
        # If top-level storage ID is 0 or nil, then we are dealing with a local file
        if(topStorageID == nil or topStorageID == 0)
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Top-level folder file record exists and is local.")
          isLocalFile = true
        else
          # Grab conf file associated with current storage ID
          conf = dbu.selectRemoteStorageConfById(topStorageID)
          conf = JSON.parse(conf[0]["conf"])
          storageType = conf["storageType"]
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Top-level folder file record exists and is remote.")
          # If our storage type is FTP, then we will create an FTP Storage Helper
          if(storageType == "FTP")
            # Grab the Genboree FTP DBRC host / prefix from that storage conf.
            ftpDbrcHost = conf["dbrcHost"]
            ftpDbrcPrefix = conf["dbrcPrefix"]
            ftpBaseDir = conf["baseDir"]
            # Create the Genboree FTP storage helper using that information.
            # Here, since we're creating a Genboree-based FTP Storage Helper, we give groupName and dbName as parameters.
            # These are used to build the file base for the current user's files.
            storageHelper = BRL::Genboree::StorageHelpers::FtpStorageHelper.new(ftpDbrcHost, ftpDbrcPrefix, ftpBaseDir, topStorageID, groupName, dbName, muted, userId)
            $stderr.debugPuts(__FILE__, __method__, "STATUS", "Created storage helper for FTP-backed storage.")
          end
        end
      end
      # If we're working with a local file, we'll create a local Storage Helper
      if(isLocalFile)
        storageHelper = BRL::Genboree::StorageHelpers::LocalStorageHelper.new(groupName, dbName, userId)
      end
      return storageHelper
    end

  end #class
end ; end; end # module BRL ; module Genboree ; module Tools
