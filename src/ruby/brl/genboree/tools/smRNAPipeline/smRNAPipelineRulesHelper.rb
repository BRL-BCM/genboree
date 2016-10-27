require 'brl/genboree/tools/workbenchRulesHelper'
require 'brl/genboree/tools/workbenchFormHelper'
require 'brl/genboree/rest/helpers/trackApiUriHelper'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require 'brl/genboree/rest/helpers/fileApiUriHelper'
require 'uri'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/rest/apiCaller'
require "brl/genboree/helpers/sniffer"
include BRL::Genboree::REST

module BRL ; module Genboree ; module Tools
  class SmRNAPipelineRulesHelper < WorkbenchRulesHelper
    
    TOOL_ID = 'smRNAPipeline'
    
    def rulesSatisfied?(wbJobEntity, sectionsToSatisfy=[ :inputs, :outputs, :context, :settings ], toolIdStr=@toolIdStr)
      # Apply basic rules from the rules file (counts, basic types, other simple things)
      errorMsgArr = []
      rulesSatisfied = super(wbJobEntity, sectionsToSatisfy, toolIdStr)
      if(rulesSatisfied)
        # Must pass the rest of the checks as well
        inputs = wbJobEntity.inputs
        outputs = wbJobEntity.outputs
        
        # ------------------------------------------------------------------
        # Check Inputs/Outputs
        # ------------------------------------------------------------------
        fileList = @fileApiHelper.expandFileContainers(wbJobEntity.inputs, @userId)
        wbJobEntity.inputs = fileList
        inputs = wbJobEntity.inputs
        # ---------------------------------------------------------------------------------------
        # Check 1: Make sure the genome version is currently supported by SmallRNA-seq Pipeline
        # ---------------------------------------------------------------------------------------
        genomesSatisfied = true
        targetDbUriObj = URI.parse(outputs[0])
        apiCaller = ApiCaller.new(targetDbUriObj.host, "#{targetDbUriObj.path}?", @hostAuthMap)
        apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
        apiCaller.get()
        resp = JSON.parse(apiCaller.respBody)['data']
        genomeVersion = resp['version'].decapitalize
        wbJobEntity.settings['genomeVersion'] = genomeVersion
        gbSmallRNASeqPipelineGenomesInfo = JSON.parse(File.read(@genbConf.gbSmallRNASeqPipelineGenomesInfo))
        if(!gbSmallRNASeqPipelineGenomesInfo.key?(genomeVersion))
          wbJobEntity.context['wbErrorMsg'] = "INVALID GENOME: The genome assembly version: #{genomeVersion} is not currently supported by SmallRNA-seq Pipeline. Supported genomes include: #{gbSmallRNASeqPipelineGenomesInfo.keys.join(',')}. Please contact the Genboree Administrator for adding support for this genome."
          genomesSatisfied = false
          rulesSatisfied = false
        end

        if(genomesSatisfied)  # If genome is not supported, then do not process any further
          # If user submits empty folder / entity list, then provide error message
          if(inputs.size < 1)
            wbJobEntity.context['wbErrorMsg'] = "INVALID NUMBER OF INPUTS: If you submit a folder/entity list, you must give at least 1 input FASTQ/SRA file (no empty folders!)."
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
            fileSizeSatisfied = true
            fileFormatSatisfied = true
            inputs.each { |file|
              fileSizeSatisfied = checkFileSize(file)
              if(fileSizeSatisfied)
                fileFormatSatisfied = sniffFastqFormat(file)
                unless(fileFormatSatisfied)
                  errorMsgArr.push("INVALID_FILE_FORMAT: Input file #{file} is not in FASTQ/SRA format. Please check the file format.")
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
          rcscUri << "/file/smallRNAseqPipeline_v#{@toolVersion}/#{CGI.escape(wbJobEntity.settings['analysisName'])}/jobFile.json?"
          apiCaller = ApiCaller.new(host, rcscUri, @hostAuthMap)
          apiCaller.initInternalRequest(@rackEnv, genbConf.machineNameAlias) if(@rackEnv)
          apiCaller.get()
          if(apiCaller.succeeded?) # Failed: job dir already exists
            wbJobEntity.context['wbErrorMsg'] = "A job with the analysis name: #{wbJobEntity.settings['analysisName']} has already been launched before. Please select a different job name."
          else
            settings =  wbJobEntity.settings
            # Check 2: Ensure adapter sequence has only ATGCN characters
            adapterSequence = settings['adapterSequence'].to_s
            if(!adapterSequence.empty? and adapterSequence !~ /^[ATGCNatgcn]+$/)
              wbJobEntity.context['wbErrorMsg'] = "Adapter sequence contains characters other than [ATGCN]. Please check your adapter sequence and try again."
              rulesSatisfied = false
            else
              rulesSatisfied = true
            end
          end # if(apiCaller.succeeded?)
        end # if(sectionsToSatisfy.include?(:settings))
      end # if(rulesSatisfied)
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
      end # 
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
        fileFormatSatisfied = true # File is compressed (not text), so assume format is true and check if file is FASTQ/SRA in the wrapper
      else
      # To check FASTQ/SRA format if file is not compressed and not empty
        fileUriObj = URI.parse(fileName)
        apiCaller = ApiCaller.new(fileUriObj.host, "#{fileUriObj.path}/sniffedType?", @hostAuthMap)
        apiCaller.initInternalRequest(@rackEnv, genbConf.machineNameAlias) if(@rackEnv)
        apiCaller.get()
        sniffedType = JSON.parse(apiCaller.respBody)['data']['text']
        if(sniffedType != 'fastq' and sniffedType != 'sra')
          fileFormatSatisfied = false # Since file is not fastq or sra, return false
        end
      end
      return fileFormatSatisfied
    end

    # It's a good idea to catch any potential errors now instead of relying on the job to do validation because,
    # the job may get queued and the user wouldn't be notified  for an unnecessarily long time that they have something minor wrong with their inputs.
    #
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
  end #class
end ; end; end # module BRL ; module Genboree ; module Tools
