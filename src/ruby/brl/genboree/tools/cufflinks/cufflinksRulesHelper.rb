require 'brl/genboree/tools/workbenchRulesHelper'
require 'brl/genboree/tools/workbenchFormHelper'
require 'brl/genboree/rest/helpers/trackApiUriHelper'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require 'uri'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/rest/wrapperApiCaller'
include BRL::Genboree::REST

module BRL ; module Genboree ; module Tools
  class CufflinksRulesHelper < WorkbenchRulesHelper

    TOOL_ID = 'cufflinks'

    def rulesSatisfied?(wbJobEntity, sectionsToSatisfy=[ :inputs, :outputs, :context, :settings ], toolIdStr=@toolIdStr)
      # Apply basic rules from the rules file (counts, basic types, other simple things)
      rulesSatisfied = super(wbJobEntity, sectionsToSatisfy, toolIdStr)

      if(rulesSatisfied)
        @dbu = BRL::Genboree::DBUtil.new("#{@genbConf.dbrcKey}", nil, nil)
        # Must pass the rest of the checks as well
        rulesSatisfied = false
        outputs = wbJobEntity.outputs
        inputs = wbJobEntity.inputs
        apiKey = BRL::Genboree::GenboreeUtil.getSuperuserDbrc(@genbConf, @genbConf.dbrcFile)
        @user = apiKey.user
        @password = apiKey.password
        # ------------------------------------------------------------------
        # Check Inputs/Outputs
        # ------------------------------------------------------------------
        userId = wbJobEntity.context['userId']
        # Check 1: are all the input files from the same db version?
        unless(checkDbVersions(inputs + outputs, skipNonDbUris=true)) # Failed
          wbJobEntity.context['wbErrorMsg'] = "Database version of one or more input file(s) do not match target database."
        else
          # Check 2: If the user has dragged over a folder, it must contain a bam file
          filesSatisfied = true
          fileCount = 0
          errorMsg = ""
          fileList = []
          folder = false
          if(@fileApiHelper.extractName(inputs[0]).nil?) # For a file folder
            folder = true
            inputUri = URI.parse(inputs[0])
            apiCaller = WrapperApiCaller.new(inputUri.host, inputUri.path, userId)
            apiCaller.initInternalRequest(@rackEnv, genbConf.machineNameAlias) if(@rackEnv)
            apiCaller.get()
            resp = JSON.parse(apiCaller.respBody)['data']
            resp.each { |file|
               fileName = file['refs'][BRL::Genboree::REST::Data::DatabaseFileEntity::REFS_KEY]
               if(fileName =~ /\.bam/) # A good way to check??
                 fileCount += 1
                 fileList << fileName
               end
             }
            if(fileCount != 1)
              filesSatisfied = false
              errorMsg = "INVALID_INPUT: bam file not found (or too many?) in the input folder."
            end
          end
          unless(filesSatisfied)
            wbJobEntity.context['wbErrorMsg'] = errorMsg
          else
            wbJobEntity.inputs = fileList if(folder)
            rulesSatisfied = true
          end

        end
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
          rcscUri << "/file/Cufflinks/#{CGI.escape(wbJobEntity.settings['analysisName'])}/jobFile.json?"
          apiCaller = WrapperApiCaller.new(host, rcscUri, userId)
          apiCaller.initInternalRequest(@rackEnv, genbConf.machineNameAlias) if(@rackEnv)
          apiCaller.get()
          if(apiCaller.succeeded?) # Failed: job dir already exists
            wbJobEntity.context['wbErrorMsg'] = "A job with the analysis name: #{wbJobEntity.settings['analysisName']} has already been launched before. Please select a different job name."
          else
            rulesSatisfied = true
          end
        end
      end
      return rulesSatisfied
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
      end

      # Clean up helpers, which cache many things
      @trkApiHelper.clear() if(!@trkApiHelper.nil?)
      @dbApiHelper.clear() if(!@dbApiHelper.nil?)
      return warningsExist
    end
  end
end ; end; end # module BRL ; module Genboree ; module Tools
