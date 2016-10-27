require 'brl/genboree/tools/workbenchRulesHelper'
require 'brl/genboree/tools/workbenchFormHelper'
require 'brl/genboree/rest/helpers/trackApiUriHelper'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require 'brl/genboree/rest/helpers/groupApiUriHelper'
require 'uri'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/rest/apiCaller'
include BRL::Genboree::REST
module BRL ; module Genboree ; module Tools
  class QiimeRulesHelper < WorkbenchRulesHelper

    TOOL_ID = 'qiime'

    def rulesSatisfied?(wbJobEntity, sectionsToSatisfy=[ :inputs, :outputs, :context, :settings ], toolIdStr=@toolIdStr)
      # Apply basic rules from the rules file (counts, basic types, other simple things)
      rulesSatisfied = super(wbJobEntity, sectionsToSatisfy, toolIdStr)

      if(rulesSatisfied)
        @dbu = BRL::Genboree::DBUtil.new("#{@genbConf.dbrcKey}", nil, nil)

        # Create API-Oriented Helpers that will help us do checking in a performant manner:
        @trkApiHelper = BRL::Genboree::REST::Helpers::TrackApiUriHelper.new(@dbu, @genbConf)
        @dbApiHelper = BRL::Genboree::REST::Helpers::DatabaseApiUriHelper.new(@dbu, @genbConf)
        @gpApiHelper = BRL::Genboree::REST::Helpers::GroupApiUriHelper.new(@dbu, @genbConf)
        outputs = wbJobEntity.outputs
        userId = wbJobEntity.context['userId']
        # ------------------------------------------------------------------
        # CHECK SETTINGS
        # ------------------------------------------------------------------
        if(sectionsToSatisfy.include?(:settings))
          # Check :settings together with info from :outputs :
          unless( sectionsToSatisfy.include?(:outputs) and  sectionsToSatisfy.include?(:inputs) )
            raise ArgumentError, "Cannot validate just :settings for this tool without info provided in both :inputs and :outputs."
          end
          # Check 1: Does the job dir already exist?
          # We need to check which output is the db, since QIIME additionally takes a project as output
          dbUri = nil
          outputs.each { |output|
            if(output =~ BRL::Genboree::REST::Helpers::DatabaseApiUriHelper::NAME_EXTRACTOR_REGEXP)
              dbUri = output
              break
            end
          }
          genbConf = BRL::Genboree::GenboreeConfig.load()
          dbrcFile = File.expand_path(ENV['DBRC_FILE'])
          user = @superuserApiDbrc.user
          pass = @superuserApiDbrc.password
          rulesSatisfied = false
          uri = URI.parse(dbUri)
          host = uri.host
          rcscUri = uri.path
          rcscUri = rcscUri.chomp("?")
          rcscUri << "/file/MicrobiomeWorkBench/#{CGI.escape(wbJobEntity.settings['studyName'])}/QIIME/#{CGI.escape(wbJobEntity.settings['jobName'])}/jobFile.json?"
          apiCaller = ApiCaller.new(host, rcscUri, @hostAuthMap)
          apiCaller.initInternalRequest(@rackEnv, genbConf.machineNameAlias) if(@rackEnv)
          apiCaller.get()
          if(apiCaller.succeeded?) # Failed: job dir already exists
            wbJobEntity.context['wbErrorMsg'] = "A job with the job name: #{wbJobEntity.settings['jobName']} has already been launched before for the study: #{wbJobEntity.settings['studyName']}. Please select a different job name."
          else
            rulesSatisfied = true
          end
        end
      end

      # Clean up helpers, which cache many things
      @trkApiHelper.clear() if(!@trkApiHelper.nil?)
      @dbApiHelper.clear() if(!@dbApiHelper.nil?)

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
