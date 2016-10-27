require 'brl/genboree/tools/workbenchRulesHelper'
require 'brl/genboree/tools/workbenchFormHelper'
require 'brl/genboree/rest/helpers/trackApiUriHelper'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require 'uri'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/rest/apiCaller'
include BRL::Genboree::REST

module BRL ; module Genboree ; module Tools
  class StructuralVariantDetectionRulesHelper < WorkbenchRulesHelper

    TOOL_ID = 'structuralVariantDetection'

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
        if(inputs.size != 0)
          dbVer1 = @dbApiHelper.dbVersion(inputs[0], @hostAuthMap)
          match = true
          inputs.each  {|file|
            if(@dbApiHelper.dbVersion(file, @hostAuthMap) != dbVer1)
              match = false
              break
            end
          }
          if(!match) # Failed: All files do not come from the same db versions
            wbJobEntity.context['wbErrorMsg'] = "Invalid Inputs: All the input files(s) do not belong to the same database version.  "
          else
            # Check 3: the input db version must match the output db version
            if(dbVer1 != @dbApiHelper.dbVersion(outputs[0])) # Failed: input and output db versions don't match
              wbJobEntity.context['wbErrorMsg'] = "Invalid Inputs: The database version of the input files(s) must match the version of the output database. "
            else
              # Check 4: Must have at least 2 files
              if(inputs.size < 2)
                wbJobEntity.context['wbErrorMsg'] = "Invalid Inputs: You MUST have at least 2 input files to run this tool. "
              else
                rulesSatisfied = true
              end
            end
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
          rcscUri << "/file/#{CGI.escape("Structural Variation")}/BreakPoints/#{CGI.escape(wbJobEntity.settings['analysisName'])}/jobFile.json?"
          apiCaller = ApiCaller.new(host, rcscUri, @hostAuthMap)
          apiCaller.initInternalRequest(@rackEnv, genbConf.machineNameAlias) if(@rackEnv)
          apiCaller.get()
          if(apiCaller.succeeded?) # Failed: job dir already exists
            wbJobEntity.context['wbErrorMsg'] = "A job with the analysis name: #{wbJobEntity.settings['analysisName'].inspect} has already been launched before. Please select a different analysis name."
          else
            # Check 2: lowerBound should be a positive integer
            lowerBound = wbJobEntity.settings['lowerBound']
            if(lowerBound.nil? or lowerBound.empty? or lowerBound !~ /^\d+$/ or lowerBound.to_i < 0)
              wbJobEntity.context['wbErrorMsg'] = "Lower Bound should be a positive integer (greater than or equal to 0)."
            else
              # Check 3: UpperBound should be a positive integer and greater than LowerBound
              upperBound = wbJobEntity.settings['upperBound']
              if(upperBound.nil? or upperBound.empty? or upperBound !~ /^\d+$/ or upperBound.to_i <= lowerBound.to_i)
                 wbJobEntity.context['wbErrorMsg'] = "Upper Bound should be a positive integer and greater than Lower Bound (greater than or equal to 0)."
              else
                upperBoundFailed = wbJobEntity.settings['upperBoundFailed']
                if(upperBoundFailed.nil? or upperBoundFailed.empty? or upperBoundFailed !~ /^\d+$/ or upperBoundFailed.to_i < 0)
                  wbJobEntity.context['wbErrorMsg'] = "Upper Bound Failed should be positive integer (greater than or equal to 0)."
                else
                  # Check 4: we should have equal number of inputTypes (fwd and rev)
                  fwdCount = 0
                  revCount = 0
                  inputs.size.times { |ii|
                    inputType = wbJobEntity.settings["inputType_#{ii}"]
                    $stderr.puts "inputType: #{inputType.inspect}"
                    if(inputType == 'Fwd')
                      fwdCount += 1
                    else
                      revCount += 1
                    end
                  }
                  if(fwdCount != revCount)
                    wbJobEntity.context['wbErrorMsg'] = "You must have equal number of Fwd and Rev input types. "
                  else
                    rulesSatisfied = true
                  end
                end
              end
            end
          end
        end
      end
        # ------------------------------------------------------------------
        # CHECK SETTINGS
        # ------------------------------------------------------------------

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
