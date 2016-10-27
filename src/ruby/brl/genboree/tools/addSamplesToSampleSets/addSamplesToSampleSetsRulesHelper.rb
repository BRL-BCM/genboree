require 'brl/genboree/tools/workbenchRulesHelper'
require 'brl/genboree/tools/workbenchFormHelper'
require 'brl/genboree/rest/helpers/trackApiUriHelper'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require 'brl/genboree/rest/helpers/fileApiUriHelper'
require 'brl/genboree/rest/helpers/sampleSetApiUriHelper'
require 'brl/genboree/rest/helpers/sampleApiUriHelper'
require 'uri'
require 'brl/genboree/abstract/resources/user'
require 'brl/genboree/dbUtil'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/rest/apiCaller'
include BRL::Genboree::REST

module BRL ; module Genboree ; module Tools
  class AddSamplesToSampleSetsRulesHelper < WorkbenchRulesHelper

    TOOL_ID = 'addSamplesToSampleSets'

    def rulesSatisfied?(wbJobEntity, sectionsToSatisfy=[ :inputs, :outputs, :context, :settings ], toolIdStr=@toolIdStr)
      # Apply basic rules from the rules file (counts, basic types, other simple things)
      rulesSatisfied = super(wbJobEntity, sectionsToSatisfy, toolIdStr)

      if(rulesSatisfied)
        @dbu = BRL::Genboree::DBUtil.new("#{@genbConf.dbrcKey}", nil, nil)


        # Must pass the rest of the checks as well
        rulesSatisfied = false
        inputs = wbJobEntity.inputs
        outputs = wbJobEntity.outputs
        # ------------------------------------------------------------------
        # Check Inputs/Outputs
        # ------------------------------------------------------------------
        # Check 1: does user have write permission to the db?
        userId = wbJobEntity.context['userId']
        @hostAuthMap = Abstraction::User.getHostAuthMapForUserId(@dbu, userId)
        unless(@dbApiHelper.accessibleByUser?(@dbApiHelper.extractPureUri(outputs.first), userId, CAN_WRITE_CODES))
          # FAILED: doesn't have write access to output database
          wbJobEntity.context['wbErrorMsg'] =
          {
            :msg => "Access Denied: You don't have permission to write to the output database.",
            :type => :writeableDbs,
            :info => @dbApiHelper.accessibleDatabasesHash(outputs, userId, CAN_WRITE_CODES)
          }
        else # OK: user can write to output database
          # Check 2: Make sure user doesn't has only one type of input.
          samplesPresent = false
          sampleSetPresent = false
          filePresent = false
          inputs.each { |input|
            if(input =~ BRL::Genboree::REST::Helpers::SampleSetApiUriHelper::NAME_EXTRACTOR_REGEXP) # sampleSet
              sampleSetPresent = true
            elsif(input =~ BRL::Genboree::REST::Helpers::SampleApiUriHelper::NAME_EXTRACTOR_REGEXP) # sample
              samplesPresent = true
            elsif(input =~ BRL::Genboree::REST::Helpers::FileApiUriHelper::NAME_EXTRACTOR_REGEXP) # file
              filePresent = true
            else
              # Do nothing
            end
          }
          if(filePresent and sampleSetPresent and samplesPresent)
            wbJobEntity.context['wbErrorMsg'] = "You can only drag over one type of input. "
          else
            # Check 3: if the input is a file, validate the file: all samples should be in same db as target sampleSet and all samples should exist
            fileOk = true
            error = ''
            if(!inputs.empty? and inputs[0] =~ BRL::Genboree::REST::Helpers::FileApiUriHelper::NAME_EXTRACTOR_REGEXP)
              genbConf = BRL::Genboree::GenboreeConfig.load()
              apiDbrc = @superuserApiDbrc
              uri = URI.parse(inputs[0])
              rcscUri = uri.path.gsub("/files/", "/file/")
              apiCaller = ApiCaller.new(uri.host, "#{rcscUri}/data?", @hostAuthMap)
              retVal = ""
              # Making internal API call
              apiCaller.initInternalRequest(@rackEnv, genbConf.machineNameAlias) if(@rackEnv)
              resp = apiCaller.get()
              if(apiCaller.succeeded?)
                retVal = apiCaller.respBody
                retIO = StringIO.new(retVal)
                # collect sample names.
                sampleNames = []
                retIO.each_line { |line|
                  line.strip!
                  next if(line.nil? or line.empty? or line =~ /^\s*$/)
                  sampleNames.push(line)
                }
                retIO.close()
                if(sampleNames.empty?)
                  fileOk = false
                  error = 'No samples provided in file'
                end
                # Make sure all samples exist
                sampleUri = "#{@dbApiHelper.extractPureUri(outputs[0]).chomp("?")}/sample"
                absentList = []
                sampleNames.each { |sample|
                  absentList.push(sample) if(!@sampleApiHelper.exists?("#{sampleUri}/#{CGI.escape(sample)}?"))
                }
                if(!absentList.empty?)
                  fileOk = false
                  error = "The following samples could not be found: #{absentList.join(",")}"
                end
              else
                fileOk = false
                error = apiCaller.respBody.inspect
              end
            end
            unless(fileOk)
              wbJobEntity.context['wbErrorMsg'] = error
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
      else # No warnings for now
        warningsExist = false
      end

      # Clean up helpers, which cache many things
      @trkApiHelper.clear() if(!@trkApiHelper.nil?)
      @dbApiHelper.clear() if(!@dbApiHelper.nil?)

      return warningsExist
    end
  end
end ; end; end # module BRL ; module Genboree ; module Tools
