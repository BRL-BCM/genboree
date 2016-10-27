require 'brl/genboree/tools/workbenchRulesHelper'
require 'brl/genboree/tools/workbenchFormHelper'
require 'brl/genboree/rest/helpers/fileApiUriHelper'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require 'brl/genboree/rest/helpers/groupApiUriHelper'

module BRL ; module Genboree ; module Tools
  class EpigenomePercentileQCRulesHelper < WorkbenchRulesHelper
    RESULTS_FILES_BASE = "Epigenomic%20Quality%20Reports"

    TOOL_ID = 'epigenomePercentileQC'

    def rulesSatisfied?(wbJobEntity, sectionsToSatisfy=[ :inputs, :outputs, :context, :settings ], toolIdStr=@toolIdStr)
      # Apply basic rules from the rules file (counts, basic types, other simple things)
      rulesSatisfied = super(wbJobEntity, sectionsToSatisfy, toolIdStr)

      if(rulesSatisfied)
        @dbu = BRL::Genboree::DBUtil.new("#{@genbConf.dbrcKey}", nil, nil)
        # Must pass the rest of the checks as well
        rulesSatisfied = false

        # ------------------------------------------------------------------
        # Check Inputs/Outpus
        # ------------------------------------------------------------------
        if(sectionsToSatisfy.include?(:inputs) or sectionsToSatisfy.include?(:outputs))
          # Check :inputs & :outputs together:
          if( (sectionsToSatisfy.include?(:inputs) and !sectionsToSatisfy.include?(:outputs)) or
              (sectionsToSatisfy.include?(:outputs) and !sectionsToSatisfy.include?(:inputs)))
            raise ArgumentError, "Cannot validate just :inputs or just :outputs, only both together."
          else
            inputs = wbJobEntity.inputs
            outputs = wbJobEntity.outputs
          end

          # CHECK 1: Does user have write access to output database?
          outputDbUri = outputs.first
          userId = wbJobEntity.context['userId']
          unless(@dbApiHelper.accessibleByUser?(outputDbUri, userId, CAN_WRITE_CODES))
            outputGrpName = @grpApiHelper.extractName(outputDbUri)
            # FAILED: doesn't have write access to output database
            wbJobEntity.context['wbErrorName'] = 'Database Access Denied'
            wbJobEntity.context['wbErrorMsg'] =
            {
              :msg => "You don't have permission to write to the output database. You must have write permission so the tool can save its report there. You can request write permission from an administrator of the '#{outputGrpName}' group.",
              :type => :writeableDbs,
              :info => @dbApiHelper.accessibleDatabasesHash(outputs, userId, CAN_WRITE_CODES)
            }
          else # OK: user can write to output database
            # ALL OK
            rulesSatisfied = true
          end
        end

        # ------------------------------------------------------------------
        # CHECK SETTINGS
        # ------------------------------------------------------------------
        if(sectionsToSatisfy.include?(:settings))
          # Check :settings together with info from :outputs :
          unless( sectionsToSatisfy.include?(:outputs) )
            raise ArgumentError, "Cannot validate just :settings without info provided in :outputs."
          end

          rulesSatisfied = false

          # CHECK 1: Does the analysis name already exist as a Epigenomic%20Quality%20Reports/ sub-dir in output database?
          analysisName = wbJobEntity.settings['experimentName']
          escAnalysisName = analysisName.split(/\//).map{|xx| CGI.escape(xx) }.join('/')
          filesRoot = @fileApiHelper.filesDirForDb(wbJobEntity.outputs.first)
          analysisSubDir = "#{filesRoot}/#{RESULTS_FILES_BASE}/#{escAnalysisName}"
          if(File.exists?(analysisSubDir))
            # FAILED: experiment name exists
            wbJobEntity.context['wbErrorName'] = "Analysis Name Already Exists"
            wbJobEntity.context['wbErrorMsg'] =
            {
              :msg => "There is already an Epigenomic Percentile-Based QC analysis called '#{analysisName}' in the output database '#{@dbApiHelper.extractName(wbJobEntity.outputs.first)}'. Please pick a different name for your analysis.",
              :type => :analysisNameExists
            }
          else
            rulesSatisfied = true
          end
        end
      end

      # Clean up helpers, which cache many things
      @fileApiHelper.clear() if(!@fileApiHelper.nil?)
      @dbApiHelper.clear() if(!@dbApiHelper.nil?)
      @grpApiHelper.clear() if(!@grpApiHelper.nil?)

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
        # No warnings known yet.
        warningsExist = false
      end

      # Clean up helpers, which cache many things
      # - no helpers yet

      return warningsExist
    end
  end
end ; end end # module BRL ; module Genboree ; module Tools
