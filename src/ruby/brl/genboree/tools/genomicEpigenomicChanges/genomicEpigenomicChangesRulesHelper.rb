require 'brl/genboree/tools/workbenchRulesHelper'
require 'brl/genboree/tools/workbenchFormHelper'
require 'brl/genboree/rest/helpers/trackApiUriHelper'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require 'uri'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/rest/apiCaller'
include BRL::Genboree::REST

module BRL ; module Genboree ; module Tools
  class GenomicEpigenomicChangesRulesHelper < WorkbenchRulesHelper

    TOOL_ID = 'genomicEpigenomicChanges'

    def rulesSatisfied?(wbJobEntity, sectionsToSatisfy=[ :inputs, :outputs, :context, :settings ], toolIdStr=@toolIdStr)
      # Apply basic rules from the rules file (counts, basic types, other simple things)
      rulesSatisfied = super(wbJobEntity, sectionsToSatisfy, toolIdStr)

      if(rulesSatisfied)
        @dbu = BRL::Genboree::DBUtil.new("#{@genbConf.dbrcKey}", nil, nil)
        # Must pass the rest of the checks as well
        rulesSatisfied = false
        outputs = wbJobEntity.outputs
        inputs = wbJobEntity.inputs
        dbrcFile = File.expand_path(ENV['DBRC_FILE'])
        user = @superuserApiDbrc.user
        pass = @superuserApiDbrc.password
        # ------------------------------------------------------------------
        # Check Inputs/Outputs
        # ------------------------------------------------------------------
        userId = wbJobEntity.context['userId']

        # Check 2: Need to make sure all dragged folders come from the 'Basic Set Operations on Structural Variants' tool
        validFolder = true
        maxInsertSize = []
        error = ''
        inputs.each { |input|
          if(input !~ BRL::Genboree::REST::Helpers::TrackApiUriHelper::NAME_EXTRACTOR_REGEXP)
            # First read json file
            input.gsub!("/files/", "/file/")
            uri = URI.parse(input)
            host = uri.host
            path = "#{uri.path.chomp("?")}/jobFile.json/data?"
            apiCaller = ApiCaller.new(host, path, @hostAuthMap)
            apiCaller.initInternalRequest(@rackEnv, genbConf.machineNameAlias) if(@rackEnv)
            t1 = Time.now
            apiCaller.get()
            if(!apiCaller.succeeded?) # Failed
              validFolder = false
              error = "BAD INPUT FOLDER: Could not find valid jobFile.json file, indicating the input folder does not correspond to the output of a previously run job. All input folders MUST come from the 'Basic Set Operations On Structural Variants' tool."
              break
            else
              idxFileContent = apiCaller.respBody.dup
              $stderr.puts "DEBUG.A: index get returned (#{Time.now - t1}):\n#{idxFileContent}"
              retVal = JSON.parse(idxFileContent)
              if(retVal['context']['toolIdStr'] != 'basicSetOperationsOnStructuralVariants')
                validFolder = false
                error = "BAD INPUT FOLDER (2): All input folders MUST be come from the 'Basic Set Operations On Structural Variants' tool. "
                break
              end
              # Also read the summary file (which has 'Maximum Insert Size')
              # We are doing this here to avoid polluting the UI
              path = "#{uri.path.chomp("?")}/summary_#{CGI.escape(retVal['settings']['analysisName'])}.txt/data?"
              apiCaller = ApiCaller.new(host, path, @hostAuthMap)
              apiCaller.initInternalRequest(@rackEnv, genbConf.machineNameAlias) if(@rackEnv)
              apiCaller.get()
              if(!apiCaller.succeeded?) # Failed
                validFolder = false
                error = "Could not read file: summary_#{CGI.escape(retVal['settings']['analysisName'])}.txt from the folder: #{input.inspect}"
                break
              else
                retVal = apiCaller.respBody
                buffIO = StringIO.new(retVal)
                buffIO.each_line { |line|
                  line.strip!
                  next if(line.nil? or line.empty? or line =~ /^\s*$/ or line =~ /^#/)
                  avps = line.split(/\t/)
                  maxInsertSize.push(avps[1].to_i) if(avps[0] == 'Maximum Insert Size')
                }
              end
            end
            wbJobEntity.settings['maxInsertSize'] = maxInsertSize.max()
          end
        }
        unless(validFolder)
          wbJobEntity.context['wbErrorMsg'] = error
        else
          # Check3: The target db must be either 'hg18' or 'hg19'
          dbVersion = @dbApiHelper.dbVersion(outputs[0])
          if(dbVersion != 'hg18' and dbVersion != 'hg19')
            wbJobEntity.context['wbErrorMsg'] = "The target database MUST be either 'hg18' or 'hg19'"
          else
            rulesSatisfied = true
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
          rulesSatisfied = false
          # Check 2: The dir for the job should not already exist
          # Find database amongst outputs
          output = nil
          outputs.each { |anOutput|
            pureUri = @dbApiHelper.extractPureUri(anOutput)
            if(pureUri)
              output = pureUri
              break # done, found which output is a database
            end
          }
          uri = URI.parse(output)
          host = uri.host
          rcscUri = uri.path
          rcscUri = rcscUri.chomp("?")
          rcscUri << "/file/#{CGI.escape("Structural Variation")}/#{CGI.escape("Genomic Epigenomic Changes")}/#{CGI.escape(wbJobEntity.settings['analysisName'])}/jobFile.json?"
          apiCaller = ApiCaller.new(host, rcscUri, @hostAuthMap)
          apiCaller.initInternalRequest(@rackEnv, genbConf.machineNameAlias) if(@rackEnv)
          apiCaller.get()
          if(apiCaller.succeeded?) # Failed: job dir already exists
            wbJobEntity.context['wbErrorMsg'] = "A job with the analysis name: #{wbJobEntity.settings['analysisName'].inspect} has already been launched before. Please select a different analysis name."
          else
            # Check 3: radius should be a positive integer
            radius = wbJobEntity.settings['radius']
            if(radius.nil? or radius.empty? or radius !~ /^\d+$/ or radius.to_i < 0)
              wbJobEntity.context['wbErrorMsg'] = "Radius should be a positive integer (greater than or equal to 0)."
            else
              rulesSatisfied = true
            end
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
