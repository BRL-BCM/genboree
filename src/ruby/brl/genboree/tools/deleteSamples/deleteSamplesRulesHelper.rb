require 'brl/genboree/tools/workbenchRulesHelper'
require 'brl/genboree/tools/workbenchFormHelper'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require 'brl/genboree/rest/helpers/sampleApiUriHelper'
require 'uri'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/rest/apiCaller'
include BRL::Genboree::REST

module BRL ; module Genboree ; module Tools
  class DeleteSamplesRulesHelper < WorkbenchRulesHelper
    TOOL_LABEL = 'Remove Samples'
    TOOL_ID = 'removeSamples'
    TOOL_TYPE = 'Utility'
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
        # Check 1: does user have access to the samples
        userId = wbJobEntity.context['userId']
        access = true        
        # flexible inputs with expandSampleContainers
        sampleUriArray = @sampleApiHelper.expandSampleContainers(inputs, userId)
        # allow this modified input to be accessible by workbenchDialog.rhtml and others
        wbJobEntity.inputs = sampleUriArray
        # preprocess sample names and sample attributes
        dbSamplesMap = {}
        sampleUriArray.each{ |input|
          # scan each input for its db and only check db permissions
          dbUri = @dbApiHelper.extractPureUri(input)
          if(dbSamplesMap[dbUri].nil?)
            dbSamplesMap[dbUri] = []
          end
          dbSamplesMap[dbUri] << @sampleApiHelper.extractName(input)
        }
        # check permissions
        access = testUserPermissions(dbSamplesMap.keys(), 'w')
        unless(access)
          # FAILED: doesn't have write access to output database
          wbJobEntity.context['wbErrorMsg'] =
          {
            :msg => "Access Denied: You don't have permission to delete the sample(s) in the input databases.",
            :type => :writeableDbs,
            :info => @dbApiHelper.accessibleDatabasesHash(dbSamplesMap.keys(), userId, CAN_WRITE_CODES)
          }
        else # OK: user can write to input database
          rulesSatisfied = true
        end
        # ------------------------------------------------------------------
        # CHECK SETTINGS
        # ------------------------------------------------------------------
        if(sectionsToSatisfy.include?(:settings))
          rulesSatisfied = false
          multiSelectList = wbJobEntity.settings['multiSelectInputList']
          $stderr.puts "multiSelectList: #{multiSelectList.inspect}"
          if(multiSelectList.nil? or multiSelectList.empty?)
            wbJobEntity.context['wbErrorMsg'] = "You must select at least one sample to delete. "
          else
            wbJobEntity.inputs = multiSelectList
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
      inputs = wbJobEntity.inputs
      if(wbJobEntity.context['warningsConfirmed'])
        # The user has confirmed the warnings and wants to proceed
        warningsExist = false
      else
        multiSelectList = wbJobEntity.settings['multiSelectInputList']
        nonEmptyFolders = []
        if(!multiSelectList.nil? and !multiSelectList.empty?)
          warningMsg = "The following samples are going to be deleted:"
          warningMsg << "<ul>"
          multiSelectList.sort.each { |sample|
            if(sample =~ BRL::Genboree::REST::Helpers::SampleApiUriHelper::NAME_EXTRACTOR_REGEXP)
              warningMsg << "<li>#{@sampleApiHelper.extractName(sample)}</li>"
            else
              subdir = @sampleApiHelper.subdir(sample).chomp("?")
              warningMsg << "<li>#{CGI.unescape(subdir)}</li>"
              # We need to check if the folder is empty or not and warn the user if it isn't
              uri = URI.parse(sample)
              apiCaller = ApiCaller.new(uri.host, uri.path, @hostAuthMap)
              # Making internal API call
              apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
              apiCaller.get()
              resp = JSON.parse(apiCaller.respBody)['data']
              if(!resp.empty?)
                nonEmptyFolders << subdir
              end
            end
          }
          if(!nonEmptyFolders.empty?)
            nonEmptyFolderswarning = "The following folder(s) will be RECURSIVELY deleted along with ALL of their contents:"
            nonEmptyFolderswarning << "<ul>"
            nonEmptyFolders.each { |folder|
              nonEmptyFolderswarning << "<li>#{CGI.unescape(folder)}</li>"
            }
            nonEmptyFolderswarning << "</ul></br>"
          end
          warningMsg << "</ul>  "
          warningMsg = nonEmptyFolderswarning + warningMsg if(!nonEmptyFolders.empty?)
          wbJobEntity.context['wbErrorMsg'] = warningMsg
          wbJobEntity.context['wbErrorMsgHasHtml'] = true
        else
          $stderr.puts "no sample selected"
          wbJobEntity.context['wbErrorMsg'] = "You must select at least one sample to delete. "
        end
      end
      @sampleApiHelper.clear() if(!@sampleApiHelper.nil?)
      return warningsExist
    end
  end
end ; end; end # module BRL ; module Genboree ; module Tools
