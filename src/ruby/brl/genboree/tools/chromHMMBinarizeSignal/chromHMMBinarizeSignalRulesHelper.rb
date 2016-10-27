require 'uri'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/rest/apiCaller'
require 'brl/genboree/tools/workbenchRulesHelper'
require 'brl/genboree/tools/workbenchFormHelper'
require 'brl/genboree/rest/helpers/trackApiUriHelper'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require 'brl/genboree/rest/helpers/trackEntityListApiUriHelper'
include BRL::Genboree::REST

module BRL ; module Genboree ; module Tools
  class ChromHMMBinarizeSignalRulesHelper < WorkbenchRulesHelper

    TOOL_ID = 'chromHMMBinarizeSignal'

    def rulesSatisfied?(wbJobEntity, sectionsToSatisfy=[ :inputs, :outputs, :context, :settings ], toolIdStr=@toolIdStr)
      # Apply basic rules from the rules file (counts, basic types, other simple things)
      rulesSatisfied = super(wbJobEntity, sectionsToSatisfy, toolIdStr)

      if(rulesSatisfied)
        @dbu = BRL::Genboree::DBUtil.new("#{@genbConf.dbrcKey}", nil, nil)
        rulesSatisfied = false
        outputs = wbJobEntity.outputs
        inputs = wbJobEntity.inputs
        apiKey = BRL::Genboree::GenboreeUtil.getSuperuserDbrc(@genbConf, @genbConf.dbrcFile)
        @user = apiKey.user
        @password = apiKey.password
        # ------------------------------------------------------------------
        # Check Inputs/Outputs
        # ------------------------------------------------------------------
        @userId = wbJobEntity.context['userId']
        # TODO: Check that the input dir appears to contain signal files
        #inputDir = wbJobEntity.inputs.first
        #rulesSatisfied = true if(inputDir)
        fileSatisfied = true
        tmpInput = Array.new()
        if(wbJobEntity.inputs.size == 1)
        inputFiles = @fileApiHelper.expandFileContainers(wbJobEntity.inputs.first, @userId)
        $stderr.puts "@inputs: #{wbJobEntity.inputs}"
        inputFiles.each { |fileUri|
          uriObj = URI.parse(fileUri)
          fileName = File.basename(uriObj.path.chomp('?'))
          if(fileName !~ /_signal/)
            $stderr.debugPuts(__FILE__, __method__, "Status", "#{fileName}")
            wbJobEntity.context['wbErrorMsg'] = "String \"_signal\" missing in the fileName of the file, #{fileName}. Input is a single folder and all the files must be signal files."
            fileSatisfied = false
          end
        }
        elsif(wbJobEntity.inputs.size == 2)
          wbJobEntity.inputs.each{ |input|
            signal = false
            control = false
            inputFiles = @fileApiHelper.expandFileContainers(input, @userId)
            inputFiles.each { |fileUri|
              uriObj = URI.parse(fileUri)
              fileName = File.basename(uriObj.path.chomp('?'))
              if(fileName =~ /_signal/)
                signal = true
                if(control)
                  fileSatisfied = false
                  wbJobEntity.context['wbErrorMsg'] = "Signal files and control files cannot be in the same folder."
                end
              elsif(fileName =~ /_controlsignal/)
                control = true
                if(signal)
                  fileSatisfied = false
                  wbJobEntity.context['wbErrorMsg'] = "Signal files and control files cannot be in the same folder."
                end
              else
                fileSatisfied = false
                wbJobEntity.context['wbErrorMsg'] = "FileName of the file, #{fileName} is invalid. The file Name must contain either the string \"_signal\" or \"_controlsignal\"."
              end
            }
            if(signal)
              tmpInput[0] = input
            else
              tmpInput[1] = input
            end
            $stderr.debugPuts(__FILE__, __method__, "Status", "Tmp@inputs: #{tmpInput}")
          }
        end
          unless(fileSatisfied)
            rulesSatisfied = false
          else
            rulesSatisfied = true
          end
          wbJobEntity.inputs = tmpInput if(!tmpInput.empty?)
          $stderr.debugPuts(__FILE__, __method__, "Status", "Final@inputs: #{wbJobEntity.inputs}")
        
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
          rcscUri << "/file/ChromHMMBinarizeSignal/#{CGI.escape(wbJobEntity.settings['analysisName'])}/jobFile.json?"
          apiCaller = ApiCaller.new(host, rcscUri, @hostAuthMap)
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
    end #(if rulesSatisfied)

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
