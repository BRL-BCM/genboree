require 'brl/genboree/tools/workbenchRulesHelper'
require 'brl/genboree/tools/workbenchFormHelper'
require 'brl/genboree/rest/helpers/trackApiUriHelper'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require 'brl/genboree/rest/helpers/fileApiUriHelper'
require 'brl/genboree/rest/helpers/sampleSetApiUriHelper'
require 'brl/genboree/rest/helpers/sampleApiUriHelper'
require 'uri'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/rest/wrapperApiCaller'
include BRL::Genboree::REST

module BRL ; module Genboree ; module Tools
  class AddExistUserRulesHelper < WorkbenchRulesHelper

    TOOL_ID = 'addExistUser'

    def rulesSatisfied?(wbJobEntity, sectionsToSatisfy=[ :inputs, :outputs, :context, :settings ], toolIdStr=@toolIdStr)
      # Apply basic rules from the rules file (counts, basic types, other simple things)
      rulesSatisfied = super(wbJobEntity, sectionsToSatisfy, toolIdStr)

      if(rulesSatisfied)
        @dbu = BRL::Genboree::DBUtil.new("#{@genbConf.dbrcKey}", nil, nil)
        inputs = wbJobEntity.inputs
        outputs = wbJobEntity.outputs
        userId = wbJobEntity.context['userId']
        # ------------------------------------------------------------------
        # Check Inputs/Outputs
        # ------------------------------------------------------------------
        userId = wbJobEntity.context['userId']
        if(!canonicalAddressesMatch?(URI.parse(wbJobEntity.outputs[0]).host, [@genbConf.machineName, @genbConf.machineNameAlias]))
          rulesSatisfied = false
          wbJobEntity.context['wbErrorMsg'] = "INVALID_INPUTS: This tool cannot be used across multiple hosts."
        else
          if(!testUserPermissions(wbJobEntity.outputs, 'o')) # Need admin level access
            rulesSatisfied = false
            wbJobEntity.context['wbErrorMsg'] = "ACCESS_DENIED: You need administrator level access to add users to groups."
          else
            # ------------------------------------------------------------------
            # CHECK SETTINGS
            # ------------------------------------------------------------------
            if(sectionsToSatisfy.include?(:settings))
              unless( sectionsToSatisfy.include?(:outputs) and  sectionsToSatisfy.include?(:inputs) )
                raise ArgumentError, "Cannot validate just :settings for this tool without info provided in both :inputs and :outputs."
              end
              # NOTE: This tool is not multi-host compliant. Hence, we can do dbu work directly instead of API calls.
              # Check 1: Check if the user is already part of the group
              loginOrEmail = wbJobEntity.settings['loginOrEmail']
              grpName = @grpApiHelper.extractName(outputs[0])
              grpRecs = @dbu.selectGroupByName(grpName)
              groupId = grpRecs.first['groupId']
              usersInGroup = @dbu.getUsersByGroupId(groupId, orderBy='')
              usersInGroup.each { |userRec|
                login = userRec['name']
                email = userRec['email']
                if(login == loginOrEmail)
                  wbJobEntity.context['wbErrorMsg'] = "ALREADY_EXISTS: The user: #{login} (Email: #{email}) is already a member of the group. "
                  rulesSatisfied = false
                  break
                end
              }
              if(rulesSatisfied)
                # Check 2: Check if the user exists at all
                userRecs = @dbu.getUserByName(loginOrEmail)
                if(userRecs.nil? or userRecs.empty?) # Maybe the email was provided
                  userRecs = @dbu.getUserByEmail(loginOrEmail)
                  if(userRecs.nil? or userRecs.empty?)
                    wbJobEntity.context['wbErrorMsg'] = "NOT_FOUND: The user with login/Email: #{loginOrEmail} does not exist. Please use the 'Add New user To Group' tool to add new users."
                    rulesSatisfied = false
                  end
                end
                if(rulesSatisfied)
                  login = wbJobEntity.settings['warningsSelectRadioBtn']
                  if(!login.nil? and !login.empty?) # The user was presented with a list of *matching* existing users (jobWarnings). See if the selected user is already in the group
                    userToAdd = @dbu.getUserByName(login).first['userId']
                    targetGrp = @grpApiHelper.extractName(wbJobEntity.outputs[0])
                    grpRecs = @dbu.selectGroupByName(targetGrp)
                    groupId = grpRecs.first['groupId']
                    usersInGroup = @dbu.getUsersByGroupId(groupId, orderBy='')
                    usersInGroup.each { |userRec|
                      if(login == userRec['name'])
                        email = userRec['email']
                        wbJobEntity.context['wbErrorMsg'] = "ALREADY_EXISTS: The user: #{login} (Email: #{email}) is already a member of the group. "
                        rulesSatisfied = false
                        wbJobEntity.settings['warningsSelectRadioBtn'] = ''
                        break
                      end
                    }
                  end
                  if(rulesSatisfied)
                    # These will be used by job helper
                    wbJobEntity.settings['groupId'] = groupId
                    wbJobEntity.settings['userId'] = userRecs.first['userId']
                  end
                end
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
      inputs = wbJobEntity.inputs
      if(wbJobEntity.context['warningsConfirmed'])
        # The user has confirmed the warnings and wants to proceed
        warningsExist = false
      else
        warningsExist = false
        # Check if a user with the same email exists
        email = wbJobEntity.settings['loginOrEmail']
        emailRecs = @dbu.getUserByEmail(email)
        warningsInfoStruct = []
        if(!emailRecs.nil? and !emailRecs.empty?)
          warningsExist = true
          emailRecs.each { |emailRec|
            warningsInfoStruct << [
                                    {'login' => { :value => emailRec['name'], :radio => true } },
                                    {'name' => { :value => emailRec['name'], :radio => false } },
                                    {'fName' => { :value => emailRec['firstName'], :radio => false } },
                                    {'lName' => { :value => emailRec['lastName'], :radio => false } },
                                    {'email' => { :value => emailRec['email'], :radio => false } }
                                  ]
          }
        end
        if(warningsExist)
          wbJobEntity.settings['warningsInfoStruct'] = warningsInfoStruct
        end
      end
      return warningsExist
    end
  end
end ; end; end # module BRL ; module Genboree ; module Tools
