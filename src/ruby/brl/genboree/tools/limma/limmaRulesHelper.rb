require 'brl/genboree/tools/workbenchRulesHelper'
require 'brl/genboree/tools/workbenchFormHelper'
require 'brl/genboree/rest/helpers/fileApiUriHelper'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require 'uri'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/rest/apiCaller'
include BRL::Genboree::REST

module BRL ; module Genboree ; module Tools
  class LimmaRulesHelper < WorkbenchRulesHelper

    TOOL_ID = 'limma'

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
        # Check 1: does user have write permission to the db?
        userId = wbJobEntity.context['userId']
        if(@dbApiHelper.dbVersion(@dbApiHelper.extractPureUri(inputs[0]), @hostAuthMap) != @dbApiHelper.dbVersion(@dbApiHelper.extractPureUri(inputs[1]), @hostAuthMap)) # Failed: All files do not come from the same db versions
          wbJobEntity.context['wbErrorMsg'] = "Invalid Inputs: All the input files(s) do not belong to the same database version.  "
        else
          # Check 3: the input db version must match the output db version
          if(@dbApiHelper.dbVersion(@dbApiHelper.extractPureUri(inputs[0]), @hostAuthMap) != @dbApiHelper.dbVersion(outputs[0], @hostAuthMap)) # Failed: input and output db versions don't match
            wbJobEntity.context['wbErrorMsg'] = "Invalid Inputs: The database version of the input files(s) must match the version of the output database. "
          else
            foundMetadataFile = false
            headerLine = nil
            # Check 4: The first file needs to be the metadata file
            # First we need to check the size of the "metadata" file and make sure that the user dragged the correct file.
            # Even in extreme cases, there is no reason for the metadata file to be larger than 512 Megs.
            input = inputs[0]
            uri = URI.parse(input)
            host = uri.host
            rcscPath = "#{uri.path.chomp("?")}"
            apiCaller = ApiCaller.new(host, "#{rcscPath}/size?", @hostAuthMap)
            # Making internal API call
            apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
            apiCaller.get()
            fileSize = JSON.parse(apiCaller.respBody)['data']['number'].to_i
            if(fileSize > 512 * 1024 * 1024)
              wbJobEntity.context['wbErrorMsg'] = "INVALID_INPUTS: Your metadata file appears to be unusually large (> 512 Megs). Are you sure you dragged the correct metadata file? Due to certain limitations, we do not support metadata files larger than 512 Megs."
            else
              # File size looks OK, get the data
              apiCaller = ApiCaller.new(host, "#{rcscPath}/data?", @hostAuthMap)
              # Making internal API call
              apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
              resp = ""
              orphan = nil
              apiCaller.get() { |chunk|
                chunkIO = StringIO.new(chunk)
                chunkIO.each_line { |line|
                  line = orphan + line if(!orphan.nil?)
                  orphan = nil
                  if(line =~ /\n$/)
                    if(line =~ /^#/)
                      foundMetadataFile = true
                      headerLine = line.chomp  
                      break
                    end
                  else
                    orphan = line
                  end
                }
                chunkIO.close()
                break if(foundMetadataFile)
              }
              if(!apiCaller.succeeded?)
                wbJobEntity.context['wbErrorMsg'] = "Could not 'get' file #{input} (Internal API call failure)."
              else
                if(!foundMetadataFile)
                  wbJobEntity.context['wbErrorMsg'] = "INVALID_INPUTS: The first line of the metadata file does not start with a '#'. Please make sure that the first file in the inputs panel is the metadata file."
                else
                  # we need to add 'metaDataColumns' to the setting so that the UI can make use of it
                  headerLine.sub!(/^#/, '')
                  killList = (@genbConf.microbiomeKillList.is_a?(Array) ? @genbConf.microbiomeKillList : [ @genbConf.microbiomeKillList ])
                  colHeaders = []
                  tempHeaders = headerLine.split(/\t/)
                  tempHeaders.each{|th| colHeaders << CGI.escape(th) unless (th.nil? or th.empty? or th !~/\S/)}
                  metaDataColumns = colHeaders - killList
                  wbJobEntity.settings['metaColumns'] = metaDataColumns
                  rulesSatisfied = true
                end
              end
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
        dbrcFile = File.expand_path(ENV['DBRC_FILE'])
        user = @superuserApiDbrc.user
        pass = @superuserApiDbrc.password
        output = @dbApiHelper.extractPureUri(outputs[0])
        uri = URI.parse(output)
        host = uri.host
        rcscUri = uri.path
        rcscUri = rcscUri.chomp("?")
        analysisName = CGI.escape(wbJobEntity.settings['analysisName'])
        rcscUri << "/file/LIMMA/#{analysisName}/jobFile.json?"
        apiCaller = ApiCaller.new(host, rcscUri, @hostAuthMap)
        apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
        apiCaller.get()
        if(apiCaller.succeeded?) # Failed: job dir already exists
          wbJobEntity.context['wbErrorMsg'] = "A job with the analysis name: #{analysisName.inspect} has already been launched before. Please select a different analysis name."
        else
          # Check 2: minPval must be a float b/w 0 and 1
          settings = wbJobEntity.settings
          minPval = settings['minPval']
          if(minPval.nil? or minPval.empty? or !minPval.to_s.valid?(:float) or minPval.to_f > 1 or minPval.to_f < 0)
            wbJobEntity.context['wbErrorMsg'] = "INVALID_INPUT: Minimum P Value MUST be a floating point number between 0 and 1."
          else
            # Check 3: minAdjPval must be a float b/w 0 and 1
            minAdjPval = settings['minAdjPval']
            if(minAdjPval.nil? or minAdjPval.empty? or !minAdjPval.to_s.valid?(:float) or minAdjPval.to_f > 1 or minAdjPval.to_f < 0)
              wbJobEntity.context['wbErrorMsg'] = "INVALID_INPUT: Minimum Adjusted P Value MUST be a floating point number between 0 and 1."
            else
              # Check 4: minFoldChange must be float
              minFoldChange = settings['minFoldChange']
              if(minFoldChange.nil? or minFoldChange.empty? or !minFoldChange.to_s.valid?(:float) or minFoldChange.to_f < 0)
                wbJobEntity.context['wbErrorMsg'] = "INVALID_INPUT: Minimum Fold Change MUST be a positive floating or integer value."
              else
                ## Check 5: minAveExp must be float
                #minAveExp = settings['minAveExp']
                #if(minAveExp.nil? or minAveExp.empty? or !minAveExp.to_s.valid?(:float) or minAveExp.to_f < 0)
                #  wbJobEntity.context['wbErrorMsg'] = "INVALID_INPUT: Minimum Average Exp MUST be a positive floating or integer value."
                #else
                  # Check 6: minBval must be a float
                  #minBval = settings['minBval']
                  #if(minBval.nil? or minBval.empty? or !minBval.to_s.valid?(:float))
                  #  wbJobEntity.context['wbErrorMsg'] = "INVALID_INPUT: Minimum B Value MUST be a floating or integer value."
                  #else
                    # Check 7: multiplier must be an integer and > 0
                    multiplier = settings['multiplier']
                    if(multiplier.nil? or multiplier.empty? or !multiplier.to_s.valid?(:float) or multiplier.to_f < 0)
                      wbJobEntity.context['wbErrorMsg'] = "INVALID_INPUT: Multiplier value MUST be a positive number."
                    else
                      rulesSatisfied = true
                    end
                  #end
                #end
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
      @fileApiHelper.clear() if(!@fileApiHelper.nil?)
      @dbApiHelper.clear() if(!@dbApiHelper.nil?)

      return warningsExist
    end
  end
end ; end; end # module BRL ; module Genboree ; module Tools
