require 'brl/genboree/tools/workbenchRulesHelper'
require 'brl/genboree/tools/workbenchFormHelper'
require 'brl/genboree/rest/helpers/trackApiUriHelper'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require 'uri'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/rest/apiCaller'
include BRL::Genboree::REST

module BRL ; module Genboree ; module Tools
  class MacsRulesHelper < WorkbenchRulesHelper

    TOOL_ID = 'macs'

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
          # Check 2: The inputs should be only be of one type
          filesSatisfied = true
          fileCount = 0
          errorMsg = ""
          fileList = []
          folder = false
          file = false
          entityList = false
          inputs.each { |input|
            if(input =~ /\/file\//)
              file = true
              if(folder or entityList)
                filesSatisfied = false
                errorMsg = "INVALID_INPUT: You cannot drag over two different types of input"
                break
              end
            elsif(input =~ /\/files\//)
              folder = true
              if(file or entityList)
                filesSatisfied = false
                errorMsg = "INVALID_INPUT: You cannot drag over two different types of input"
                break
              end
            else
              entityList = true
              if(file or folder)
                filesSatisfied = false
                errorMsg = "INVALID_INPUT: You cannot drag over two different types of input"
                break
              end
            end
          }
          unless(filesSatisfied)
            wbJobEntity.context['wbErrorMsg'] = errorMsg
          else
            # Check 3: We must have atleast 2 bam files
            errorMsg = ""
            if(!file) # We either have a folder or an entity list
              if(entityList)
                count = 0
                inputs.each { |input|
                  inputUri = URI.parse(input)
                  apiCaller = ApiCaller.new(inputUri.host, inputUri.path, @hostAuthMap)
                  apiCaller.initInternalRequest(@rackEnv, genbConf.machineNameAlias) if(@rackEnv)
                  apiCaller.get()
                  resp = JSON.parse(apiCaller.respBody)['data']
                  resp.each { |file|
                    fileName = file['url']
                    fileList << fileName
                  }
                  count += 1
                }
              else
                inputUri = URI.parse(inputs[0])
                apiCaller = ApiCaller.new(inputUri.host, inputUri.path, @hostAuthMap)
                apiCaller.initInternalRequest(@rackEnv, genbConf.machineNameAlias) if(@rackEnv)
                apiCaller.get()
                resp = JSON.parse(apiCaller.respBody)['data']
                count = 0
                resp.each { |file|
                  fileName = file['refs'][BRL::Genboree::REST::Data::DatabaseFileEntity::REFS_KEY]
                  fileList << fileName
                  count += 1
                }
              end
              if(fileList.size > 2 or fileList.size < 1)
                errorMsg = "INVALID_INPUT: The folder or Files Entity List should contain either 1 or 2 files. "
                wbJobEntity.context['wbErrorMsg'] = errorMsg
              else
                wbJobEntity.inputs = fileList
                rulesSatisfied = true
              end
            else
              if(inputs.size > 2 or inputs.size < 1)
                wbJobEntity.context['wbErrorMsg'] = "INVALID_INPUT: The tool requires either 1 or 2 files to run. "
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

          # Check1: A job with the same analysis name under the same target db should not exist
          output = @dbApiHelper.extractPureUri(outputs[0])
          uri = URI.parse(output)
          host = uri.host
          rcscUri = uri.path
          rcscUri = rcscUri.chomp("?")
          rcscUri << "/file/MACS/#{CGI.escape(wbJobEntity.settings['analysisName'])}/jobFile.json?"
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
