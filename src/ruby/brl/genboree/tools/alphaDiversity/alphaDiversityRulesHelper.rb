require 'brl/genboree/tools/workbenchRulesHelper'
require 'brl/genboree/tools/workbenchFormHelper'
require 'brl/genboree/rest/helpers/trackApiUriHelper'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require 'brl/genboree/rest/helpers/groupApiUriHelper'
require 'uri'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/rest/wrapperApiCaller'
include BRL::Genboree::REST
module BRL ; module Genboree ; module Tools
  class AlphaDiversityRulesHelper < WorkbenchRulesHelper

    TOOL_ID = 'alphaDiversity'

    def rulesSatisfied?(wbJobEntity, sectionsToSatisfy=[ :inputs, :outputs, :context, :settings ], toolIdStr=@toolIdStr)
      # Apply basic rules from the rules file (counts, basic types, other simple things)
      rulesSatisfied = super(wbJobEntity, sectionsToSatisfy, toolIdStr)
      @userId = wbJobEntity.context['userId']
      if(rulesSatisfied)
        @dbu = BRL::Genboree::DBUtil.new("#{@genbConf.dbrcKey}", nil, nil)

        # Must pass the rest of the checks as well
        rulesSatisfied = false
        outputs = wbJobEntity.outputs
        inputs = wbJobEntity.inputs
        userId = wbJobEntity.context['userId']
        # Check 1: See if the 'sample.metadata file is present in the input folder
        # Get the list of samples to display
        fileUri = inputs[0].gsub("/files", "/file")
        fileUri = fileUri.chomp("?")
        fileUri << "/sample.metadata/data?"
        uri = URI.parse(fileUri)
        genbConf = BRL::Genboree::GenboreeConfig.load()
        apiDbrc = @superuserApiDbrc
        apiCaller = WrapperApiCaller.new(uri.host, uri.path, @userId)
        # Do internal request if enabled (in this case, if we've been given a Rack env hash to work from)
        retVal = ""
        apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
        resp = apiCaller.get()
        if(!apiCaller.succeeded?) # Failed
          wbJobEntity.context['wbErrorMsg'] = "sample.metadata file not found in the input folder. Please run QIIME prior to running this tool to initialize the directory structure for this tool."
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

          # Check #1: Make sure at least one feature is selected from the feature list:
          featureList = wbJobEntity.settings['featureList']
          if(featureList.nil? or featureList.empty?) # Failed if none selected
            wbJobEntity.context['wbErrorMsg'] = "Bad Request: You must select at least one feature from the feature list"
          else
            # Check 2: does the dob dir already exist?
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
            # Check 1: The dir for sample set name should not exist
            uri = URI.parse(dbUri)
            host = uri.host
            rcscUri = uri.path
            rcscUri = rcscUri.chomp("?")
            rcscUri << "/file/MicrobiomeWorkBench/#{CGI.escape(wbJobEntity.settings['studyName'])}/AlphaDiversity/#{CGI.escape(wbJobEntity.settings['jobName'])}/jobFile.json?"
            apiCaller = WrapperApiCaller.new(host, rcscUri, @userId)
            apiCaller.initInternalRequest(@rackEnv, genbConf.machineNameAlias) if(@rackEnv)
            apiCaller.get()
            if(apiCaller.succeeded?) # Failed: job dir already exists
              wbJobEntity.context['wbErrorMsg'] = "A job with the job name: #{wbJobEntity.settings['jobName']} has already been launched before for the study: #{wbJobEntity.settings['studyName']}. Please select a different job name."
            else
              rulesSatisfied = true
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
