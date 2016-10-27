require 'brl/genboree/tools/workbenchRulesHelper'
require 'brl/genboree/tools/workbenchFormHelper'
require 'brl/genboree/rest/helpers/trackApiUriHelper'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require 'brl/genboree/rest/helpers/fileApiUriHelper'
require 'uri'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/rest/apiCaller'
include BRL::Genboree::REST

module BRL ; module Genboree ; module Tools
  class FileCopierRulesHelper < WorkbenchRulesHelper

    TOOL_ID = 'fileCopier'

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
        unless(@dbApiHelper.accessibleByUser?(outputs.first, userId, CAN_WRITE_CODES))
          # FAILED: doesn't have write access to output database
          wbJobEntity.context['wbErrorMsg'] =
          {
            :msg => "Access Denied: You don't have permission to write to the output database.",
            :type => :writeableDbs,
            :info => @dbApiHelper.accessibleDatabasesHash(outputs, userId, CAN_WRITE_CODES)
          }
        else # OK: user can write to output database
          # Check 2: No Input should be a folder
          noFolders = true
          inputs.each { |input|
            if(input =~ /\/files\//)
              noFolders = false
              break
            end
          }
          unless(noFolders)
            wbJobEntity.context['wbErrorMsg'] = "INVALID_INPUTS: Copying folders is not allowed."
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
        # Check if any of the files already exist in the output destination
        inputs = wbJobEntity.inputs
        outputs = wbJobEntity.outputs[0].dup()
        warnings = ""
        inputs.each { |inputFile|
          fileName = CGI.escape(File.basename(@fileApiHelper.extractName(inputFile)))
          destToCheck = nil
          subdirPath = @fileApiHelper.subdir(outputs)
          # For db or 'Files'
          if(subdirPath == "/")
            $stderr.puts "outputs: #{outputs}"
            dbUri = @dbApiHelper.extractPureUri(outputs)
            dbUri.gsub!(/\?$/, '')
            destToCheck = "#{dbUri}/file/#{fileName}?"
          else # For subdir
            dbUri = @dbApiHelper.extractPureUri(outputs)
            dbUri.gsub!(/\?$/, "")
            destToCheck = "#{dbUri}/file#{subdirPath}/#{fileName}?"
          end
          $stderr.puts "destToCheck: #{destToCheck.inspect}"
          warnings << "One or more of the files already exist in the target location. Launching the job will overwrite the existing files. " if(@fileApiHelper.exists?(destToCheck, @hostAuthMap))
          break if(!warnings.empty?)
        }
        if(warnings.empty?)
          # if moving display a warning msg
          if(wbJobEntity.settings['deleteSourceFilesRadio'] == 'move')
            warnings = "Moving file(s) involves permanently deleting them from the source database."             
          end
        end
        if(warnings.empty?)
          warningsExist = false
        else
          wbJobEntity.context['wbErrorMsg'] = warnings
        end
      end

      # Clean up helpers, which cache many things
      @trkApiHelper.clear() if(!@trkApiHelper.nil?)
      @dbApiHelper.clear() if(!@dbApiHelper.nil?)

      return warningsExist
    end
  end
end ; end; end # module BRL ; module Genboree ; module Tools
