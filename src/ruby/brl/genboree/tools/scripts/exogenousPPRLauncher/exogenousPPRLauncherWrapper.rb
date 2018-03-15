#!/usr/bin/env ruby
########################################################
############ exogenousPPRLauncher wrapper ##############
# This wrapper launches a PPR job, conditional upon    #
# a list of exogenousTaxoTree jobs finishing.          #
########################################################

require 'uri'
require 'json'
require 'brl/util/util'
require 'brl/util/emailer'
require 'brl/genboree/tools/toolWrapper'
require 'brl/genboree/tools/wrapperEmailer'
require 'brl/genboree/helpers/dataImport'
require 'brl/genboree/helpers/expander'
require 'brl/util/convertText'
require 'brl/genboree/tools/scripts/uploadTrackAnnos/uploadTrackAnnosWrapper'
require 'brl/genboree/rest/wrapperApiCaller'
require 'brl/genboree/helpers/sniffer'
require 'parallel'
require 'brl/genboree/kb/kbDoc'
require 'brl/genboree/tools/FTPtoolWrapper'
include BRL::Genboree::REST

module BRL; module Genboree; module Tools; module Scripts
  class ExogenousPPRLauncherWrapper < BRL::Genboree::Tools::ToolWrapper
    VERSION = "4.6.2"
    COMMAND_LINE_ARGS = { }
    DESC_AND_EXAMPLES = {
      :description  => "This is the wrapper for running 'exogenousPPRLauncher'. 
                        This tool uses an input list of exogenousTaxoTree jobs and launches a conditional PPR job.",
      :authors      => [ "William Thistlethwaite (thistlew@bcm.edu)" ],
      :examples     => [
        "#{File.basename(__FILE__)} --inputFile=filePath",
        "#{File.basename(__FILE__)} -j filePath",
        "#{File.basename(__FILE__)} --help"
      ]
    }
    attr_accessor :exitCode
    # Extract the relevant information to run the job
    # @return [FixNum] @exitCode code corresponding to whether tool run was successful or not (and if not, what error message should be given to user)
    def processJobConf()
      begin
        # Getting relevant variables from "context"
        @dbrcKey = @context['apiDbrcKey']
        @userId = @context['userId']
        @jobId = @context['jobId']
        @jobId = 0 unless @jobId
        @userEmail = @context['userEmail']
        @userFirstName = @context['userFirstName']
        @userLastName = @context['userLastName']
        @scratchDir = @context['scratchDir']
        @scratchDir = "." if(@scratchDir.nil? or @scratchDir.empty?)
        # Grab group name and db name
        @groupName = @grpApiHelper.extractName(@outputs[0])
        @dbName = @dbApiHelper.extractName(@outputs[0])
        # Set up format options coming from the UI
        @postProcDir = @settings['postProcDir']
        @isFTPJob = @settings['isFTPJob']
        @remoteStorageArea = @settings['remoteStorageArea'] if(@settings['remoteStorageArea'])
        @subUserId = @settings['subUserId']
        @subUserId = @userId unless(@subUserId)
        @sampleID = @settings['sampleID']
        @exogenousMappingInputDir = @settings['exogenousMappingInputDir']
        @exogenousTaxoTreeJobIDDir = @settings['exogenousTaxoTreeJobIDDir']
        @exogenousRerunDir = @settings['exogenousRerunDir']
        @exogenousJobIds = JSON.parse(File.read(@settings['filePathToListOfExogenousJobIds']))
        listOfRerunFiles = Dir.entries(@exogenousRerunDir) rescue nil
        if(@dbrcKey)
          dbrc = BRL::DB::DBRC.new(@dbrcFile, @dbrcKey)
          # get super user, pass and hostname
          user = dbrc.user
          pass = dbrc.password
          host = dbrc.driver.split(/:/).last
        else
          suDbDbrc = BRL::Genboree::GenboreeUtil.getSuperuserDbrc(@genbConf, @dbrcFile)
          user = suDbDbrc.user
          pass = suDbDbrc.password
          host = suDbDbrc.driver.split(/:/).last
        end
        # Then some exogenousSTARMapping jobs were cancelled, so we need to relaunch this job with those new IDs
        if(listOfRerunFiles and listOfRerunFiles.length() > 2)
          listOfRerunFiles.delete(".")
          listOfRerunFiles.delete("..")
          # preconditionJobsForRerunningJob will hold all of the job IDs that need to finish in order for this tool (exogenousPPRLauncher) to re-run.
          # Some of these jobs may already be finished (because they ran earlier successfully)
          preconditionJobsForRerunningJob = []
          @exogenousSTARMappingId = "exogenousSTARMapping"
          @eplToolId = @toolConf.getSetting('info', 'idStr')
          # Create a reusable ApiCaller instance for launching each runExceRpt job
          apiCaller = BRL::Genboree::REST::ApiCaller.new(host, "/REST/v1/genboree/tool/{toolId}/job", user, pass)
          # Traverse all of the jobs that already finished and add a condition hash for each to our preconditionJobs array.
          # Note that met has been set to be true for all of these jobs (they won't be re-run)
          @exogenousJobIds.each_key { |jobId|
            condition = {
              "type" => "job",
             "expires" => (Time.now + Time::WEEK_SECS * 4).to_s,
              "met" => true,
              "condition"=> {
                "dependencyJobUrl" => "http://#{host}/REST/v1/job/#{jobId}",
                "acceptableStatuses" =>
                {
                  "killed"=>true,
                  "failed"=>true,
                  "completed"=>true,
                  "partialSuccess"=>true,
                  "canceled"=>true
                }
              }
            }
            $stderr.debugPuts(__FILE__, __method__, "STATUS", "Condition connected with exogenousSTARMapping job #{jobId} (job type: #{@exogenousJobIds[jobId]}): #{condition.inspect}")
            preconditionJobsForRerunningJob << condition
          }
          # Next, we'll add a condition for each exogenous STAR Mapping job that we have to re-run.
          # Note that met will be set to false for all of these jobs (they won't be re-run)
          listOfRerunFiles.each { |currentRerunId|
            currentRerunId.chomp!(".txt")
            condition = {
              "type" => "job",
             "expires" => (Time.now + Time::WEEK_SECS * 4).to_s,
              "met" => false,
              "condition"=> {
                "dependencyJobUrl" => "http://#{host}/REST/v1/job/#{currentRerunId}",
                "acceptableStatuses" =>
                {
                  "killed"=>true,
                  "failed"=>true,
                  "completed"=>true,
                  "partialSuccess"=>true,
                  "canceled"=>true
                }
              }
            }
            @exogenousJobIds[currentRerunId] = "Exogenous STAR Mapping Job"
            $stderr.debugPuts(__FILE__, __method__, "STATUS", "Condition connected with exogenousSTARMapping job #{currentRerunId} (job type: #{@exogenousJobIds[currentRerunId]}): #{condition.inspect}")
            preconditionJobsForRerunningJob << condition
            # We will delete the rerun file since we've submitted the associated job
            File.delete("#{@exogenousRerunDir}/#{currentRerunId}.txt")
          }
          File.open(@settings['filePathToListOfExogenousJobIds'], 'w') { |file| file.write(JSON.pretty_generate(@exogenousJobIds)) }
          # Finally, we relaunch our exogenousPPRLauncher job with the new list of conditions
          exogenousPPRLauncher(host, user, pass, preconditionJobsForRerunningJob)
          # Then, we will cancel this job by raising an error with exit code 15 (reserved for cancellation)
          @errUserMsg = "At least some of your samples failed processing through exceRpt,\nlikely due to insufficient memory.\nWe will re-run those failed samples with more memory.\nAfter those samples are re-run, we will run this job again.\n"
          @exitCode = 15
          raise @errUserMsg
        end
      rescue => err
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Error with processJobConf: #{err}")
        @errUserMsg = "ERROR: Could not set up required variables for running job." if(@errUserMsg.nil?)
        @errInternalMsg = err
        @errBacktrace = err.backtrace.join("\n")
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Backtrace: #{@errBacktrace}")
        @exitCode = 22
      end
      return @exitCode
    end

    # Runs the script
    # @return [FixNum] @exitCode code corresponding to whether tool run was successful or not (and if not, what error message should be given to user)
    def run()
      begin
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Starting exogenousPPRLauncher job (version #{@toolVersion})")
        user = pass = host = nil
        if(@dbrcKey)
          dbrc = BRL::DB::DBRC.new(@dbrcFile, @dbrcKey)
          # get super user, pass and hostname
          user = dbrc.user
          pass = dbrc.password
          host = dbrc.driver.split(/:/).last
        else
          suDbDbrc = BRL::Genboree::GenboreeUtil.getSuperuserDbrc(@genbConf, @dbrcFile)
          user = suDbDbrc.user
          pass = suDbDbrc.password
          host = suDbDbrc.driver.split(/:/).last
        end
        # Set up API URI helper for processing inputs currently in email to user
        @apiUriHelper = BRL::Genboree::REST::Helpers::ApiUriHelper.new()
        # Read in lists of exogenous taxo tree IDs
        exogenousTaxoTreeJobIDs = []
        exogenousTaxoTreeJobIDFiles = Dir.entries(@exogenousTaxoTreeJobIDDir)
        exogenousTaxoTreeJobIDFiles.delete(".")
        exogenousTaxoTreeJobIDFiles.delete("..")
        exogenousTaxoTreeJobIDFiles.each { |currentJobIDFile|
          currentJobIDFileContents = File.read("#{@exogenousTaxoTreeJobIDDir}/#{currentJobIDFile}")
          currentJobIDFileContents.each_line { |currentJobID|
            exogenousTaxoTreeJobIDs << currentJobID
          }
        }
        # Create condition for each exogenous taxo tree ID
        exogenousTaxoTreeConds = []
        exogenousTaxoTreeJobIDs.each { |currentId|
          condition = {
           "type" => "job",
           "expires" => (Time.now + Time::WEEK_SECS * 4).to_s,
            "met" => false,
            "condition"=> {
              "dependencyJobUrl" => "http://#{host}/REST/v1/job/#{currentId}",
              "acceptableStatuses" =>
              {
                "killed"=>true,
                "failed"=>true,
                "completed"=>true,
                "partialSuccess"=>true,
                "canceled"=>true
              }
            }
          }
          exogenousTaxoTreeConds << condition
        }
        # Submit PPR job (conditional upon exogenousTaxoTree jobs grabbed above)
        postProcessing(host, user, pass, exogenousTaxoTreeConds)
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "DONE exogenousPPRLauncher job (version #{@toolVersion}). END.")
        # DONE exogenousTaxoTree
      rescue => err
        @err = err
        @errUserMsg = "ERROR: Running of Exogenous Taxonomy Tree Generation (version #{@toolVersion}) failed (#{err.message.inspect})." if(@errUserMsg.nil?)
        @errInternalMsg = "ERROR: Unexpected error trying to run Exogenous Taxonomy Tree Generation (version #{@toolVersion})." if(@errInternalMsg.nil?)
        @exitCode = 30 if(@exitCode == 0)
      end
      return @exitCode
    end

###### *****************************
###### Methods used in this workflow
###### *****************************

    # Produce a valid job conf for exogenousSTARMapping tool and then submit ESM job. ESM job will be conditional on all successfully launched runExceRpt jobs finishing (success or failure).
    # @param [String] host host name
    # @param [String] user user name
    # @param [String] pass password
    # @param [Array] conditions array of different job conditions required for exogenousPPRLauncher job to launch
    # @return [nil]
    def exogenousPPRLauncher(host, user, pass, conditions)
      # Produce exogenousPPRLauncher job file
      eplJobConf = createEPLJobConf(conditions)
      # Launch exogenousPPRLauncher job
      submitEPLJob(host, user, pass, eplJobConf)
      return
    end
   
    # Method to create exogenousPPRLauncher jobFile.json used in submitEPLJob()
    # @settings [Array] conditions array of job conditions used as preconditions for exogenousPPRLauncher job
    # @return [JSON] job conf for exogenousPPRLauncher tool
    def createEPLJobConf(conditions)
      eplJobConf = @jobConf.deep_clone()
      ## Define context
      eplJobConf['context']['toolIdStr'] = @eplToolId
      ## Define settings
      eplJobConf['settings']['exogenousMapping'] = "on"
      # We will submit a conditional job. Its preconditions will be the exogenousSTARMapping jobs grabbed before. 
      eplJobConf['preconditionSet'] =  {
        "willNeverMatch"=> false,
        "numMet"=> 0,
        "someExpired"=> false,
        "count"=> 0,
        "preconditions"=> conditions
      }
      # Write jobConf hash to tool specific jobFile.json
      eplJobFile = "#{@exogenousMappingInputDir}/eplJobFile.json"
      File.open(eplJobFile,"w") do |eplJob|
        eplJob.write(JSON.pretty_generate(eplJobConf))
      end
      return eplJobConf
    end
    
    # Method to call exogenousPPRLauncher job for successful samples
    # @param [String] host host name
    # @param [String] user user name 
    # @param [String] pass password 
    # @param [JSON] eplJobConf job conf for current exogenousPPRLauncher job
    # @return [nil]
    def submitEPLJob(host, user, pass, eplJobConf)
      apiCaller = BRL::Genboree::REST::ApiCaller.new(host, "/REST/v1/genboree/tool/exogenousPPRLauncher/job", user, pass)
      apiCaller.put({}, eplJobConf.to_json)
      unless(apiCaller.succeeded?)
        $stderr.debugPuts(__FILE__, __method__, "EXOGENOUS PPR LAUNCHER JOB SUBMISSION FAILURE", apiCaller.respBody.inspect)
        @errUserMsg = "We could not submit your exogenousPPRLauncher job as a conditional job."
        raise @errUserMsg
      else
        $stderr.debugPuts(__FILE__, __method__, "EXOGENOUS PPR LAUNCHER JOB SUBMISSION SUCCESS", apiCaller.respBody.inspect)
      end
      return
    end

    # Produce a valid job conf for processPipelineRuns tool and then submit PPR job. PPR job will be conditional on all successfully launched exogenousTaxoTree jobs finishing (success or failure).
    # @param [String] host host name
    # @param [String] user user name
    # @param [String] pass password
    # @param [Array] exogenousTaxoTreeConds array containing exogenousTaxoTree job conditions
    # @return [nil]
    def postProcessing(host, user, pass, exogenousTaxoTreeConds)
      # Produce processPipelineRuns job file
      createPPRJobConf(exogenousTaxoTreeConds)
      # Submit processPipelineRuns job
      submitPPRJob(host, user, pass)
      return
    end
   
    # Method to create processPipelineRuns jobFile.json used in submitPPRJob()
    # @param [Array] exogenousTaxoTreeConds array containing exogenousTaxoTree job conditions
    # @return [nil]
    def createPPRJobConf(exogenousTaxoTreeConds)
      @pprJobConf = @jobConf.deep_clone()
      # Create dummy input for processPipelineRuns 
      @pprJobConf['inputs'] = ["http://genboree.org/REST/v1/grp/#{CGI.escape("Examples and Test Data")}/db/#{CGI.escape("smallRNA-seq Pipeline - Example Data")}/file/placental_serum_plasma_SRA_Study_SRP018255_4_samples.tar.gz?"]
      ## Define context
      @pprJobConf['context']['toolIdStr'] = "processPipelineRuns"
      # We will submit a conditional job. Its preconditions will be the exogenousTaxoTree jobs launched above. 
      @pprJobConf['preconditionSet'] =  {
        "willNeverMatch"=> false,
        "numMet"=> 0,
        "someExpired"=> false,
        "count"=> 0,
        "preconditions"=> exogenousTaxoTreeConds
      }
      # Write jobConf hash to tool specific jobFile.json
      @pprJobFile = "#{@pprJobConf['settings']['postProcDir']}/pprJobFile.json"
      File.open(@pprJobFile,"w") do |pprJob|
        pprJob.write(JSON.pretty_generate(@pprJobConf))
      end
      return
    end
    
    # Method to submit processPipelineRuns job
    # @param [String] host host name
    # @param [String] user user name 
    # @param [String] pass password
    # @return [nil]
    def submitPPRJob(host, user, pass)
      apiCaller = BRL::Genboree::REST::ApiCaller.new(host, "/REST/v1/genboree/tool/processPipelineRuns/job", user, pass)
      apiCaller.put({}, @pprJobConf.to_json)
      unless(apiCaller.succeeded?)
        $stderr.debugPuts(__FILE__, __method__, "PROCESS PIPELINE RUNS JOB SUBMISSION FAILURE", apiCaller.respBody.inspect)
        @errUserMsg = "We could not submit your processPipelineRuns job as a conditional job."
        raise @errUserMsg
      else
        $stderr.debugPuts(__FILE__, __method__, "PROCESS PIPELINE RUNS JOB SUBMISSION SUCCESS", apiCaller.respBody.inspect)
      end
      return
    end

############ END of methods specific to this runExceRpt wrapper
    
########### Email 

    # Method to send success e-mail to user
    def prepSuccessEmail()
      # Update jobFile.json with updated contents
      toolJobFile = "#{@scratchDir}/jobFile.json"
      File.open(toolJobFile,"w") do |jobFile|
        jobFile.write(JSON.pretty_generate(@jobConf))
      end
      return nil
    end
    
    # Method to send failure e-mail to user
    def prepErrorEmail()
      # Update jobFile.json with updated contents
      toolJobFile = "#{@scratchDir}/jobFile.json"
      File.open(toolJobFile,"w") do |jobFile|
        jobFile.write(JSON.pretty_generate(@jobConf))
      end
      # Email object
      emailErrorObject                = BRL::Genboree::Tools::WrapperEmailer.new(@toolTitle,@userEmail,@jobId)
      emailErrorObject.userFirst      = @userFirstName
      emailErrorObject.userLast       = @userLastName
      emailErrorObject.analysisName   = @analysisName
      emailErrorObject.inputsText     = nil
      outputsText                     = buildSectionEmailSummary(@outputs[0])
      emailErrorObject.outputsText    = outputsText
      emailErrorObject.settings       = @jobConf['settings']
      emailErrorObject.errMessage     = @errUserMsg
      emailErrorObject.exitStatusCode = @exitCode
      emailErrorObject.erccTool = true
      # Remove settings that are unnecessary for user e-mail
      cleanUpSettingsForEmail()
      if(@suppressEmail)
        return nil
      else
        return emailErrorObject
      end
    end

    # When we send our success or failure email, there are certain settings that we don't want to send the user (because they're not helpful, redundant, etc.).
    # @return [nil]  
    def cleanUpSettingsForEmail()
      if(@settings['endogenousLibraryOrder'])
        @settings['endogenousLibraryOrder'].gsub!("gencode", "Gencode")
        @settings['endogenousLibraryOrder'].gsub!(",", " > ")
      end
      @settings.delete("indexBaseName") unless(@settings['useLibrary'] =~ /uploadNewLibrary/)
      @settings.delete("newSpikeInLibrary") unless(@settings['useLibrary'] =~ /uploadNewLibrary/)
      @settings.delete("existingLibraryName") unless(@settings['useLibrary'] =~ /useExistingLibrary/)
      @settings.delete("jobSpecificSharedScratch")
      @settings.delete("listOfJobIds")
      @settings.delete("autoDetectAdapter") unless(@settings['adapterSequence'] == "other")
      @settings.delete("manualAdapter") unless(@settings['adapterSequence'] == "other" and @settings['autoDetectAdapter'] == "no")
      @settings.delete("otherDataRepo") unless(@settings['anticipatedDataRepo'] == "Other")
      @settings.delete("piID")
      @settings.delete("platform")
      @settings.delete("processingPipeline")
      @settings.delete("processingPipelineIdAndVersion")
      @settings.delete("processingPipelineVersion")
      unless(@settings["randomBarcodesEnabled"])
        @settings.delete("randomBarcodeLength")
        @settings.delete("randomBarcodeLocation")
        @settings.delete("randomBarcodeStats")
      end
      @settings.delete("subjobDir")
      @settings.delete("toolVersionPPR")
      @settings["priorityList"].gsub!(",", " > ") if(@settings["priorityList"])
      @settings.delete("adSeqParameter")
      @settings.delete("adapterSequence")
      @settings.delete("anticipatedDataRepo")
      @settings.delete("bowtieSeedLength")
      @settings.delete("calib")
      @settings.delete("exRNAHost")
      @settings.delete("exRNAKb")
      @settings.delete("exRNAKbGroup")
      @settings.delete("exRNAKbProject")
      @settings.delete("failedFtpDir")
      @settings.delete("finalizedMetadataDir")
      @settings.delete("finishedFtpDir")
      @settings.delete("dataArchiveLocation")
      @settings.delete("genboreeKbArea")
      @settings.delete("manifestLocation")
      @settings.delete("metadataArchiveLocation")
      @settings.delete("outputHost")
      @settings.delete("anticipatedDataRepo")
      @settings.delete("dataRepoSubmissionCategory")
      @settings.delete("dbGaP")
      @settings.delete("grantNumber")
      @settings.delete("piName")
      @settings.delete("javaRam")
      @settings.delete("localExecution")
      @settings.delete("numThreads")
      @settings.delete("postProcOutputDir")
      @settings.delete("useLibrary")
      @settings.delete("endogenousMismatch")
      @settings.delete("exogenousMapping")
      @settings.delete("exogenousMismatch")
      @settings.delete("genomeBuild")
      @settings.delete("manifestFile")
      @settings.delete("postProcDir")
      @settings.delete("subUserId")
      @settings.delete("uploadRawFiles")
      @settings.delete("remoteStorageArea") if(@settings["remoteStorageArea"] == nil)
      # Delete local path to post-processing input dir
      @settings.delete('postProcDir')
      @settings.delete('exogenousMappingInputDir')
      # Delete information about number of threads / tasks for exogenous mapping (used in exogenousSTARMapping wrapper)
      @settings.delete('numThreadsExo')
      @settings.delete('numTasksExo') 
      @settings.delete("toggleMultiSelectListButton")
      @settings.delete('numberField_fractionForMinBaseCallQuality')
      @settings.delete('numberField_minReadLength')
      @settings.delete('numberField_readRemainingAfterSoftClipping')
      @settings.delete('numberField_trimBases5p')
      @settings.delete('numberField_trimBases3p')
      @settings.delete('numberField_minAdapterBases3p')
      @settings.delete('numberField_downsampleRNAReads')
      @settings.delete('numberField_bowtieSeedLength')
      @settings.delete('minBaseCallQuality') if(@settings['exceRptGen'] == 'thirdGen') # We can delete minimum base-call quality if user submitted 3rd gen exceRpt job
      @settings.delete('exRNAAtlasURL')
      @settings.delete("uploadReadCountsDocs")
      @settings.delete('listOfExogenousTaxoTreeJobIds')
      @settings.delete('exogenousTaxoTreeJobIDDir')
      @settings.delete('exogenousRerunDir')
      @settings.delete('filePathToListOfExogenousJobIds')
      @settings.delete('exogenousClaves')
      @settings.delete('backupFtpDir')
      @settings.delete('importantJobIdsDir')
    end

    def customBuildSectionEmailSummary(section)
      sectionHash = {}
      countDisplay = 1
      ##Only display 10 input items as max
      section.each { |file|
        uriObj = URI.parse(file)
        scheme = uriObj.scheme
        if(scheme =~ /file/)
          type = scheme
          baseName = File.basename(uriObj.path)
        else
          type = @apiUriHelper.extractType(file)
          baseName = File.basename(@apiUriHelper.extractName(file))
        end
        sectionHash["#{countDisplay}. #{type.capitalize}"] = baseName
        # We want to display only 9 files and keep record if there are more than
        # 9,
        # which would be shown by "...."
        if(countDisplay == 9 and section.size > 9)
          sectionHash["99"] = "....."
          break
        end
        countDisplay += 1
      }
      return sectionHash
    end

  end
end; end ; end ; end

# If we are running this file (and not using it as a library), run it:
if($0 and File.exist?($0) and BRL::Script::runningThisFile?($0, __FILE__, true))
  # Argument to main() is your specific class:
  BRL::Genboree::Tools::main(BRL::Genboree::Tools::Scripts::ExogenousPPRLauncherWrapper)
end
