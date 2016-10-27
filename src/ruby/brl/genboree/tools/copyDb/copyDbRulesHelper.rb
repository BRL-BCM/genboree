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
  class CopyDbRulesHelper < WorkbenchRulesHelper
    def rulesSatisfied?(wbJobEntity, sectionsToSatisfy=[ :inputs, :outputs, :context, :settings ], toolIdStr=@toolIdStr)
      # Apply basic rules from the rules file (counts, basic types, other simple things)
      rulesSatisfied = super(wbJobEntity, sectionsToSatisfy, toolIdStr)
      inputs = wbJobEntity.inputs
      outputs = wbJobEntity.outputs
      output = outputs[0]
      # ------------------------------------------------------------------
      # Check Inputs/Outputs
      # ------------------------------------------------------------------
      userId = wbJobEntity.context['userId']
      if(rulesSatisfied)
        permission = testUserPermissions(wbJobEntity.outputs, 'o')
        unless(permission)
          rulesSatisfied = false
          wbJobEntity.context['wbErrorMsg'] = "NO PERMISSION: You need administrator level access (in the target group) to create/clone a new database."
        else
          if(!canonicalAddressesMatch?(URI.parse(wbJobEntity.outputs[0]).host, [@genbConf.machineName, @genbConf.machineNameAlias])) # Target group should be on 'this' machine
            rulesSatisfied = false
            wbJobEntity.context['wbErrorMsg'] = "INVALID_INPUTS: This tool cannot be used across multiple hosts."
          else
            if(!canonicalAddressesMatch?(URI.parse(wbJobEntity.inputs[0]).host, [@genbConf.machineName, @genbConf.machineNameAlias])) # Source group should be on 'this' machine
              rulesSatisfied = false
              wbJobEntity.context['wbErrorMsg'] = "INVALID_INPUTS: This tool cannot be used across multiple hosts."
            end
          end
          # ------------------------------------------------------------------
          # CHECK SETTINGS
          # ------------------------------------------------------------------
          if(sectionsToSatisfy.include?(:settings))
            unless( sectionsToSatisfy.include?(:outputs) and  sectionsToSatisfy.include?(:inputs) )
              raise ArgumentError, "Cannot validate just :settings for this tool without info provided in both :inputs and :outputs."
            end
            rulesSatisfied = false
            # Check 1: The name being used to rename should not already exist
            newName = wbJobEntity.settings['newName'].strip
            shallowCopy = wbJobEntity.settings['shallowCopy']
            $stderr.debugPuts(__FILE__, __method__, "DEBUG", "shallowCopy: #{shallowCopy.inspect}")
            targetUri = URI.parse(@grpApiHelper.extractPureUri(output))
            targetHost = targetUri.host
            targetRsrcPath = targetUri.path
            apiCaller = ApiCaller.new(targetHost, "#{targetRsrcPath}/db/#{CGI.escape(newName)}?", @hostAuthMap)
            apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
            apiCaller.get()
            if(apiCaller.succeeded?)
              wbJobEntity.context['wbErrorMsg'] = "A database with the name: '#{newName}' already exists in the target group. "
            else
              # Create an empty db
              # We need the desc, species and version of the source db first
              dbUriObj = URI.parse(inputs[0])
              apiCaller = WrapperApiCaller.new(dbUriObj.host, dbUriObj.path, userId)
              apiCaller.get()
              if(apiCaller.succeeded?)
                resp = apiCaller.parseRespBody['data']
                description = resp['description']
                species = resp['species']
                version = resp['version']
                gpUriObj = URI.parse(output)
                settings = wbJobEntity.settings
                newName = settings['newName']
                apiCaller = ApiCaller.new(gpUriObj.host, "#{gpUriObj.path}/db/#{CGI.escape(newName)}", @hostAuthMap)
                apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
                payload = {"data"=>{"name"=>newName, "entrypoints"=>nil, "gbKey"=>"", "version"=>version, "description"=>description, "refSeqId"=>"", "species"=>species, "public" => false}}
                apiCaller.put(payload.to_json)
                if(!apiCaller.succeeded?)
                  wbJobEntity.context['wbErrorMsg'] = "FATAL: Could not create empty database for copying contents from old database:\n#{apiCaller.parseRespBody}"
                else
                  newDbUri = "#{output.chomp("?")}/db/#{CGI.escape(newName)}"
                  refseqRec = @dbApiHelper.tableRow(newDbUri)
                  tgtRefSeqId = refseqRec['refSeqId']
                  tgtGroupId = @grpApiHelper.tableRow(output)['groupId']
                  wbJobEntity.settings['tgtDatabaseName'] = refseqRec['databaseName']
                  wbJobEntity.settings['tgtRefseqName'] = refseqRec['refseqName']
                  wbJobEntity.settings['tgtRefSeqId'] = tgtRefSeqId
                  wbJobEntity.settings['tgtGroupId'] = tgtGroupId
                  # Do some initial work on the web server
                  `mkdir -p #{@genbConf.ridSequencesDir}/#{tgtRefSeqId}`
                  `mkdir -p #{@genbConf.gbDataFileRoot}/grp/#{tgtGroupId}/db/#{tgtRefSeqId}`
                  if(shallowCopy) # then make some links in the ridSequencesDir
                    srcRefseqRec = @dbApiHelper.tableRow(wbJobEntity.inputs[0])
                    srcRefSeqId = srcRefseqRec['refSeqId']
                    cmd = "for xx in /usr/local/brl/data/genboree/ridSequences/#{srcRefSeqId}/*; do ln -s $xx /usr/local/brl/data/genboree/ridSequences/#{refseqRec['refSeqId']}/; done"
                    `#{cmd}`
                  end
                  rulesSatisfied = true
                end
              else
                wbJobEntity.context['wbErrorMsg'] = "FATAL: Could not get information from source database: #{apiCaller.parseRespBody}"
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
      outputs = wbJobEntity.outputs
      if(wbJobEntity.context['warningsConfirmed'])
        # The user has confirmed the warnings and wants to proceed
        warningsExist = false
      else
        warningsExist = false # No warnings for now
      end
      return warningsExist
    end
  end
end ; end; end # module BRL ; module Genboree ; module Tools
