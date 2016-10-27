require 'brl/genboree/tools/workbenchRulesHelper'
require 'brl/genboree/tools/workbenchFormHelper'
require 'brl/genboree/rest/helpers/trackApiUriHelper'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require 'uri'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/rest/apiCaller'
require "brl/genboree/helpers/sniffer"
require 'tempfile'
include BRL::Genboree::REST

module BRL ; module Genboree ; module Tools
  class ChromHMMLearnModelRulesHelper < WorkbenchRulesHelper

    TOOL_ID = 'chromHMMLearnModel'

    def rulesSatisfied?(wbJobEntity, sectionsToSatisfy=[ :inputs, :outputs, :context, :settings ], toolIdStr=@toolIdStr)
      # Apply basic rules from the rules file (counts, basic types, other simple things)
      rulesSatisfied = super(wbJobEntity, sectionsToSatisfy, toolIdStr)

      if(rulesSatisfied)
        @dbu = BRL::Genboree::DBUtil.new("#{@genbConf.dbrcKey}", nil, nil)
        # Must pass the rest of the checks as well
        rulesSatisfied = false
        inputs = wbJobEntity.inputs
        outputs = wbJobEntity.outputs

        # To get the database of the output target
        # Case where the output targets contain both database and project paths
        # To extract the database irrespetive of the order
        if(wbJobEntity.outputs[0] !~ (BRL::Genboree::REST::Helpers::DatabaseApiUriHelper::NAME_EXTRACTOR_REGEXP))
          outputDb = wbJobEntity.outputs[1]
        else
          outputDb = wbJobEntity.outputs[0]
        end

        # ------------------------------------------------------------------
        # Check Inputs/Outputs
        # ------------------------------------------------------------------
        userId = wbJobEntity.context['userId']
        apiKey = BRL::Genboree::GenboreeUtil.getSuperuserDbrc(@genbConf, @genbConf.dbrcFile)
        @user = apiKey.user
        @password = apiKey.password
        fileList = []

        # ------------------------------------------------------------------
        # Check 1: Make sure all the files in the folder and entity list are from the same db version
        # ------------------------------------------------------------------
        targetDbUriObj = URI.parse(outputDb)
        apiCaller = ApiCaller.new(targetDbUriObj.host, "#{targetDbUriObj.path}?", @hostAuthMap)
        apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
        apiCaller.get()
        resp = JSON.parse(apiCaller.respBody)['data']
        genomeVersion = resp['version'].decapitalize
        wbJobEntity.settings['assembly'] = genomeVersion
        expandedInputs = inputs.dup
        filesSatisfied = true
        # To make sure all files inside entity list/folder are from same db version
        if(expandedInputs.size == 1 and inputs[0] !~ /\/file\//)
          expInputUri = URI.parse(inputs[0])
          apiCaller = ApiCaller.new(expInputUri.host, expInputUri.path, @hostAuthMap)
          apiCaller.initInternalRequest(@rackEnv, genbConf.machineNameAlias) if(@rackEnv)
          apiCaller.get()
          respInput = JSON.parse(apiCaller.respBody)['data']

          # If input is an entity list or folder, add them to expandedInputs
          # so it can be used by checkDbVersions to ensure all inputs
          # are from same db
          if(expandedInputs[0] =~ /entityList/)
            respInput.each { |file| expandedInputs << file['url'] }
          elsif(@fileApiHelper.extractName(expandedInputs[0]).nil?)
            respInput.each { |file| expandedInputs << file['refs'][BRL::Genboree::REST::Data::DatabaseFileEntity::REFS_KEY] }
          end

          # If total number of inputs including entity list (EL)/folder is
          # less than 2 (1 EL/folder + 1 file) or
          if(expandedInputs.size < 2)
            filesSatisfied = false
          end
        end # if(expandedInputs.size == 1)

        # If number of files is not satisfied, directly print the error message
        if(!filesSatisfied)
          wbJobEntity.context['wbErrorMsg'] = "INVALID_NUMBER_OF_INPUTS: Files Folder cannot be empty."
          rulesSatisfied = false
          # ------------------------------------------------------------------
          # Check 2: Are all the input files (including those inside entity lists or folders)
          # from the same db version?
          # ------------------------------------------------------------------
          # If number of files is correct but files are from different db versions
        elsif(filesSatisfied and !checkDbVersions(expandedInputs + outputs, skipNonDbUris=true))
          # FAILED: No, some versions didn't match
          wbJobEntity.context['wbErrorMsg'] =
          {
            :msg => 'Some files are from a different genome assembly version than other files, or from the output atabase.',
            :type => :versions,
            :info =>
            {
              :inputs =>  @trkApiHelper.dbVersionsHash(expandedInputs),
              :outputs => @dbApiHelper.dbVersionsHash(outputDb)
            }
          }
          rulesSatisfied = false
        else
          # ------------------------------------------------------------------
          # Check 3: Make sure the right combination of inputs has been selected
          # ------------------------------------------------------------------
          # Individual files from folder/entity list to inputs
          errorMsg = ""
          fileFormatSatisfied = true
          # For exactly 2 inputs
          if(filesSatisfied and inputs.size >= 2)
            inputs.each { |file|
              if(!@fileApiHelper.extractName(file))
                filesSatisfied = false
                errorMsg = "INVALID_INPUT: For multiple inputs, all needs to be files. "
                break
              else
                fileName = file
                fileFormatSatisfied = isBinary(fileName)
                unless(fileFormatSatisfied)
                  errorMsg = "INVALID_INPUT: The input file, #{File.basename(URI.parse(fileName).path)}does not contain the string \"binary\""
                  break
                else
                  fileList << fileName
                end
              end
            }
          elsif(filesSatisfied and inputs.size == 1)
            # If input is an entity list
            if(inputs[0] =~ /entityList/)
              respInput.each { |file|
              fileName = file['url']
              fileFormatSatisfied = isBinary(fileName)
              unless(fileFormatSatisfied)
                errorMsg = "INVALID_INPUT: The input file does not contain the string \"binary\""
                break
              else
                fileList << fileName
              end
              fileList << fileName
              }

            # If input is a folder with files
            elsif(@fileApiHelper.extractName(inputs[0]).nil?)
              respInput.each { |file|
              fileName = file['refs'][BRL::Genboree::REST::Data::DatabaseFileEntity::REFS_KEY]
              fileFormatSatisfied = isBinary(fileName)
              unless(fileFormatSatisfied)
                errorMsg = "INVALID_INPUT: The input file, #{File.basename(URI.parse(fileName).path)} does not contain the string \"binary\""
                break
              else
                fileList << fileName
              end
              fileList << fileName
              }

            # If input is a single file
            elsif(inputs[0] =~ /\/file\//)
              fileName = inputs[0]
              fileFormatSatisfied = isBinary(fileName)
              unless(fileFormatSatisfied)
                errorMsg = "INVALID_INPUT: The input file, #{File.basename(URI.parse(fileName).path)} does not contain the string \"binary\""
              else
                fileList << fileName
              end

            # If input does not satisfy any of the above conditions
            else
              filesSatisfied = false
              errorMsg = "INVALID_INPUT: You need to drag at least one binarized data file. "
            end
          else
            errorMsg = "INVALID_NUMBER_OF_INPUTS: You can give at least one binarized file data or 1 folder/entity list with at least one binarized file data in the folder/entity list. "
          end # if(filesSatisfied and inputs.size == 2)
          unless(fileFormatSatisfied)
            wbJobEntity.context['wbErrorMsg'] = errorMsg
            rulesSatisfied = false
          else
             wbJobEntity.inputs = fileList
             rulesSatisfied = true
          end # unless(fileFormatSatisfied)
        end # if(!filesSatisfied)

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
          output = @dbApiHelper.extractPureUri(outputDb)
          uri = URI.parse(output)
          host = uri.host
          rcscUri = uri.path
          rcscUri = rcscUri.chomp("?")
          rcscUri << "/file/ChromHMM%20-%20LearnModel%20-%20Results/#{CGI.escape(wbJobEntity.settings['analysisName'])}/jobFile.json?"
          apiCaller = ApiCaller.new(host, rcscUri, @hostAuthMap)
          apiCaller.initInternalRequest(@rackEnv, genbConf.machineNameAlias) if(@rackEnv)
          apiCaller.get()
          if(apiCaller.succeeded?) # Failed: job dir already exists
            wbJobEntity.context['wbErrorMsg'] = "A job with the analysis name: #{wbJobEntity.settings['analysisName']} has already been launched before. Please select a different job name."
          else # Check 2: LearnModel Specific testing
            learnModelSettingsSatisfied = true
            numStates = wbJobEntity.settings['numStates']
            if(numStates.empty? or numStates.nil? or numStates =~/[^0-9]/ or numStates.to_i <= 0)
              learnModelSettingsSatisfied = false
              errorMsg = "Invalid input type for \"numStates\". Entry must be a positive integer.\n"
            end
            init = wbJobEntity.settings['init']
            # A model file must be loaded with string "model" in the filename.
            if(init =~ /load/)
              model = false
              if(wbJobEntity.inputs.size == 1)
                learnModelSettingsSatisfied = false
                errorMsg = "Invalid number of inputs for the option \"load\". Either model or binarized file is missing."
              end
              wbJobEntity.inputs.each { |file|
                uri = URI.parse(file)
                inFile = File.basename(uri.path)
                unless(inFile =~ /_binary/)
                  if(inFile =~ /model/)
                    model = true
                  else
                  learnModelSettingsSatisfied = false
                  errorMsg = "Invalid file name for the file, #{inFile}. File names must contain the string \"_binary\"."
                  end
                end
              }
              unless(model)
                learnModelSettingsSatisfied = false
                errorMsg = "Load option is on. FAILED to locate the model file. Model filename must contain the string \"model\"."
              end
            # All the filenames must have the string "_binary".
            elsif(init =~ /information/ or init =~ /random/)
              wbJobEntity.inputs.each { |file|
                uri = URI.parse(file)
                inFile = File.basename(uri.path)
                unless(inFile =~ /_binary/)
                  learnModelSettingsSatisfied = false
                  errorMsg = "Invalid file name for the file, #{inFile}. All file names must contain the string \"_binary\"."
                end
              }
            end
            unless(learnModelSettingsSatisfied)
              rulesSatisfied = false
              wbJobEntity.context['wbErrorMsg'] = errorMsg
            else
            rulesSatisfied = true
            end
          end # if(apiCaller.succeeded?)
        end # if(sectionsToSatisfy.include?(:settings))
      end # if(rulesSatisfied)
      return rulesSatisfied
    end

    # fileName strings should contain "_binary" or "_model" for the Learnmodel
    def isBinary(file)
      uri = URI.parse(file)
      inFile = File.basename(uri.path)
      binary = true
      if(inFile =~ /_binary/ or inFile =~ /model/)
        binary = true
      else
        binary = false
      end
      return binary
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
