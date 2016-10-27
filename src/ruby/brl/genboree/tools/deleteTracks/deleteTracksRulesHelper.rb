require 'brl/genboree/tools/workbenchRulesHelper'
require 'brl/genboree/tools/workbenchFormHelper'
require 'brl/genboree/rest/helpers/trackApiUriHelper'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require 'brl/genboree/rest/helpers/classApiUriHelper'
require 'uri'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/rest/wrapperApiCaller'
include BRL::Genboree::REST

module BRL ; module Genboree ; module Tools
  class DeleteTracksRulesHelper < WorkbenchRulesHelper
    def rulesSatisfied?(wbJobEntity, sectionsToSatisfy=[ :inputs, :outputs, :context, :settings ], toolIdStr=@toolIdStr)
      rulesSatisfied = super(wbJobEntity, sectionsToSatisfy, toolIdStr)
      inputs = wbJobEntity.inputs
      # The user should have write access to all inputs since the big* files will be written to the database the track is in.
      if(rulesSatisfied)
        userId = wbJobEntity.context['userId']
        rulesSatisfied = false
        if(!@dbApiHelper.allAccessibleByUser?(inputs, userId, CAN_WRITE_CODES))
          # FAILED: doesn't have write access to source database
          wbJobEntity.context['wbErrorMsg'] =
          {
            :msg => "Access Denied: You don't have permission to write to all the source databases.",
            :type => :writeableDbs,
            :info => @dbApiHelper.accessibleDatabasesHash(inputs, userId, CAN_WRITE_CODES)
          }
        else
          # Check that all tracks are coming from the same database
          trkHash = {}
          previousDb = nil
          allDbsSame = true
          inputs.each { |input|
            if(!previousDb.nil?)
              if(@dbApiHelper.extractPureUri(input) != previousDb)
                allDbsSame = false
                break
              end
            end
            previousDb = @dbApiHelper.extractPureUri(input)
          }
          unless(allDbsSame)
            wbJobEntity.context['wbErrorMsg'] = "All input tracks MUST come from the same database. "
          else
            # Multi-host not supported
            if(!canonicalAddressesMatch?(URI.parse(wbJobEntity.inputs[0]).host, [@genbConf.machineName, @genbConf.machineNameAlias]))
              wbJobEntity.context['wbErrorMsg'] = "INVALID_INPUTS: This tool cannot be used across multiple hosts."
            else
              rulesSatisfied = true
            end
          end
          if(rulesSatisfied)
            refSeqRec = @dbApiHelper.tableRow(inputs[0])
            ftypesHash = BRL::Genboree::GenboreeDBHelper.getAllAccessibleFtypes_fast(refSeqRec['refSeqId'], userId, true, @dbu) # Will need to know which tracks are template (not editable)
            #$stderr.debugPuts(__FILE__, __method__, "DEBUG", ftypesHash.keys.inspect)
            inputs.each { |input|
              if(@trkApiHelper.extractName(input)) # For tracks
                trkName = @trkApiHelper.extractName(input)
                ftypeHash = ftypesHash[trkName]
                if(ftypeHash['dbNames'].size > 1 or ftypeHash['dbNames'][0]['dbType'] == :sharedDb)
                  trkHash[trkName] = false
                else
                  trkHash[trkName] = true
                end
              elsif(classApiHelper.extractName(input)) # For class
                className = classApiHelper.extractName(input)
                dbUri = dbApiHelper.extractPureUri(input)
                uri = dbUri.dup()
                uri = URI.parse(uri)
                rcscUri = uri.path.chomp("?")
                rcscUri << "/trks?connect=false&class=#{CGI.escape(className)}"
                # Get all tracks for this class
                apiCaller = WrapperApiCaller.new(uri.host, rcscUri, userId)
                apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
                apiCaller.get()
                resp = apiCaller.respBody()
                retVal = JSON.parse(resp)
                tracks = retVal['data']
                tracks.each { |track|
                  trkUri = "#{dbUri.chomp("?")}/trk/#{CGI.escape(track['text'])}?"
                  trkName = track['text']
                  ftypeHash = ftypesHash[trkName]
                  if(ftypeHash['dbNames'].size > 1 or ftypeHash['dbNames'][0]['dbType'] == :sharedDb)
                    trkHash[trkName] = false
                  else
                    trkHash[trkName] = true
                  end
                }
              else # For dbs
                uri = URI.parse(input)
                rcscPath = uri.path
                apiCaller = WrapperApiCaller.new(uri.host, "#{rcscPath}/trks?detailed=minDetails", userId)
                apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
                apiCaller.get()
                resp = apiCaller.respBody()
                retVal = JSON.parse(resp)
                tracks = retVal['data']
                tracks.each { |track|
                  trkName = track['name']
                  ftypeHash = ftypesHash[trkName]
                  if(ftypeHash['dbNames'].size > 1 or ftypeHash['dbNames'][0]['dbType'] == :sharedDb)
                    trkHash[trkName] = false
                  else
                    trkHash[trkName] = true
                  end
                }
              end
            }
            wbJobEntity.settings['trkHash'] = trkHash
          end
        end
        if(sectionsToSatisfy.include?(:settings))
          # There should be at least one selected tracks to delete
          trkSelected = false
          settings = wbJobEntity.settings
          baseWidget = settings['baseWidget']
          trksToDel = []
          settings.each_key { |setting|
            if(setting =~ /^#{baseWidget}/ and settings[setting] == 'on')
              trkSelected = true
              trksToDel << CGI.escape(setting.gsub(/^#{baseWidget}\|/, '').gsub(/\|delete$/, ''))
            end
          }
          unless(trkSelected)
            wbJobEntity.context['wbErrorMsg'] = "NO_TRKS_SELECTED: You must select at least one track to delete."
            rulesSatisfied = false
          else
            wbJobEntity.settings['trksToDel'] = trksToDel
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
      else # No Warnings
        warningsExist = false
      end

      # Clean up helpers, which cache many things
      @trkApiHelper.clear() if(!@trkApiHelper.nil?)
      @dbApiHelper.clear() if(!@dbApiHelper.nil?)

      return warningsExist
    end
  end
end ; end; end # module BRL ; module Genboree ; module Tools
