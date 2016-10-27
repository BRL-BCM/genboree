require 'brl/genboree/tools/workbenchRulesHelper'
require 'brl/genboree/tools/workbenchFormHelper'
require 'brl/genboree/rest/helpers/trackApiUriHelper'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require 'uri'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/rest/wrapperApiCaller'
include BRL::Genboree::REST

module BRL ; module Genboree ; module Tools
  class AtlasSNP2GenotyperRulesHelper < WorkbenchRulesHelper

    TOOL_ID = 'atlasSNP2Genotyper'

    def rulesSatisfied?(wbJobEntity, sectionsToSatisfy=[ :inputs, :outputs, :context, :settings ], toolIdStr=@toolIdStr)
      # Apply basic rules from the rules file (counts, basic types, other simple things)
      rulesSatisfied = super(wbJobEntity, sectionsToSatisfy, toolIdStr)

      if(rulesSatisfied)
        @dbu = BRL::Genboree::DBUtil.new("#{@genbConf.dbrcKey}", nil, nil)
        # Must pass the rest of the checks as well
        rulesSatisfied = false
        outputs = wbJobEntity.outputs
        inputs = wbJobEntity.inputs
        # ------------------------------------------------------------------
        # Check Inputs/Outputs
        # ------------------------------------------------------------------
        userId = wbJobEntity.context['userId']
        # Check 2: are all the input files from the same db version?
        unless(checkDbVersions(inputs + outputs, skipNonDbUris=true)) # Failed
          wbJobEntity.context['wbErrorMsg'] = "Database version of one or more input file(s) do not match target database."
        else
          rulesSatisfied = true
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

          # Check 1: Does the job dir already exist?
          genbConf = BRL::Genboree::GenboreeConfig.load()
          dbrcFile = File.expand_path(ENV['DBRC_FILE'])
          user = @superuserApiDbrc.user
          pass = @superuserApiDbrc.password
          rulesSatisfied = false
          # Check 1: The dir for sample set name should not exist
          output = @dbApiHelper.extractPureUri(outputs[0])
          uri = URI.parse(output)
          host = uri.host
          rcscUri = uri.path
          rcscUri = rcscUri.chomp("?")
          rcscUri << "/file/#{CGI.escape("Atlas2 Suite Results")}/#{CGI.escape(wbJobEntity.settings['studyName'])}/Atlas-SNP2-Genotyper/#{CGI.escape(wbJobEntity.settings['jobName'])}/jobFile.json?"
          apiCaller = WrapperApiCaller.new(host, rcscUri, userId)
          apiCaller.initInternalRequest(@rackEnv, genbConf.machineNameAlias) if(@rackEnv)
          apiCaller.get()
          if(apiCaller.succeeded?) # Failed: job dir already exists
            wbJobEntity.context['wbErrorMsg'] = "A job with the job name: #{wbJobEntity.settings['jobName']} has already been launched before for the study: #{wbJobEntity.settings['studyName']}. Please select a different job name."
          else
            # Check 2: Minimal Coverage required for high confidence SNP calls (-y) should be >= 1
            minCov = wbJobEntity.settings['minCov']
            if(minCov.nil? or minCov.empty? or minCov !~ /^\d+$/ or minCov.to_i < 1)
              wbJobEntity.context['wbErrorMsg'] = "Minimal Coverage required for high confidence SNP calls MUST be greater than or equal to 1 and an integer value"
            else
              # Check 3: If uploadSNPTrack is true the track name should be correct
              uploadSNPTrack = wbJobEntity.settings['uploadSNPTrack']
              validName = true
              if(uploadSNPTrack)
                if(wbJobEntity.settings['lffType'] !~ /^(?![:\t \n])[^:]*[^:\t \n]$/ or wbJobEntity.settings['lffSubType'] !~ /^(?![:\t \n])[^:]*[^:\t \n]$/)
                  validName = false
                end
              end
              if(!validName)
                wbJobEntity.context['wbErrorMsg'] = "The Output Track Name can not be blank, cannot contain ':', and cannot begin or end with whitespace."
              else
                rulesSatisfied = true
              end
            end
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
