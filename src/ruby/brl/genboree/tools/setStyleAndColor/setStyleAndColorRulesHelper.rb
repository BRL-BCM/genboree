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
  class SetStyleAndColorRulesHelper < WorkbenchRulesHelper
    def rulesSatisfied?(wbJobEntity, sectionsToSatisfy=[ :inputs, :outputs, :context, :settings ], toolIdStr=@toolIdStr)
      rulesSatisfied = super(wbJobEntity, sectionsToSatisfy, toolIdStr)
      inputs = wbJobEntity.inputs
      if(rulesSatisfied)
        userId = wbJobEntity.context['userId']
        # All databases must have a gbKey
        dbHash = {}
        trkHash = Hash.new { |hh,kk|
          hh[kk] = {}
        }
        settingsHash = Hash.new { |hh,kk|
          hh[kk] = {}
        }
        tmpHash = {}
        dbVer = nil
        trkName = nil
        inputs.each { |input|
          dbUri = @dbApiHelper.extractPureUri(input)
          if(!dbHash.has_key?(input))
            dbUriObj = URI.parse(dbUri)
            apiCaller = WrapperApiCaller.new(dbUriObj.host, dbUriObj.path, userId)
            apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
            apiCaller.get()
            retVal = JSON.parse(apiCaller.respBody)['data']
            if(dbVer.nil? or dbVer == retVal['version'])
              dbVer = retVal['version']
              wbJobEntity.settings["gbKey_#{dbUri}"] = retVal['gbKey']
              dbHash[dbUri] = true
            else
              wbJobEntity.context['wbErrorMsg'] = "INVALID_INPUT: All tracks must come from the same reference genome assembly."
              rulesSatisfied = false
            end
          end
        }
        # Prep some settings for the UI
        if(rulesSatisfied)
          wbJobEntity.settings["dbVersion"] = "#{dbVer[0,1].downcase}#{dbVer[1,dbVer.size]}"
          loadDefaults = wbJobEntity.settings['loadDefaults']
          inputs.each { |input|
            dbUri = nil
            if(input !~ /trks\/entityList/)
              dbUri = @dbApiHelper.extractPureUri(input)
            end
            if(dbUri and !trkHash.key?(dbUri))
              updateSettingsHash(settingsHash, dbUri, loadDefaults, userId)
            end
            if(@trkApiHelper.extractName(input)) # For tracks
              trkName = @trkApiHelper.extractName(input)
              trkHash[dbUri][trkName] = {:style => settingsHash[dbUri][:style][trkName], :color => settingsHash[dbUri][:color][trkName]}
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
                trkName = track['text']
                trkUri = "#{dbUri.chomp("?")}/trk/#{CGI.escape(trkName)}?"
                trkHash[dbUri][trkName] = {:style => settingsHash[dbUri][:style][trkName], :color => settingsHash[dbUri][:color][trkName]}
              }
            elsif(input =~ /trks\/entityList/) # For track entity list
              uri = URI.parse(input)
              rcscUri = uri.path
              apiCaller = WrapperApiCaller.new(uri.host, rcscUri, userId)
              apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
              apiCaller.get()
              resp = apiCaller.respBody()
              retVal = JSON.parse(resp)
              tracks = retVal['data']
              tracks.each { |track|
                trackUrl = track['url']
                dbUri = @dbApiHelper.extractPureUri(trackUrl)
                if(!trkHash.key?(dbUri))
                  updateSettingsHash(settingsHash, dbUri, loadDefaults, userId)
                end
                trkName = @trkApiHelper.extractName(trackUrl)
                trkHash[dbUri][trkName] = {:style => settingsHash[dbUri][:style][trkName], :color => settingsHash[dbUri][:color][trkName]}
              }
            else
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
                trkHash[dbUri][trkName] = {:style => settingsHash[dbUri][:style][trkName], :color => settingsHash[dbUri][:color][trkName]}
              }
            end
          }
          wbJobEntity.settings['trkHash'] = trkHash
          wbJobEntity.settings['showSetDefBtn'] = ( !testUserPermissions(trkHash.keys, 'o') ? false : true )
          # ------------------------------------------------------------------
          # CHECK SETTINGS
          # ------------------------------------------------------------------
          if(sectionsToSatisfy.include?(:settings))
            # Check :settings together with info from :outputs :
            unless( sectionsToSatisfy.include?(:outputs) and  sectionsToSatisfy.include?(:inputs) )
              raise ArgumentError, "Cannot validate" 
            end
          end
        end
      end
      return rulesSatisfied
    end

    def updateSettingsHash(settingsHash, dbUri, loadDefaults, userId)
      dbUriObj = URI.parse(dbUri)
      apiCaller = WrapperApiCaller.new(dbUriObj.host, "#{dbUriObj.path}/trks/defaultColor?", userId)
      apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
      apiCaller.get()
      tmpHash = JSON.parse(apiCaller.respBody())['data']['hash']
      unless(loadDefaults)
        apiCaller.setRsrcPath("#{dbUriObj.path}/trks/color?")
        apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
        apiCaller.get()
        resp = JSON.parse(apiCaller.respBody())['data']['hash']
        resp.each_key { |key|
          tmpHash[key] = resp[key] if(!resp[key].nil?) 
        }
      end
      tmpHash.each_key { |key|
        tmpHash[key] = '#000000' if(tmpHash[key].nil?)  
      }
      settingsHash[dbUri][:color] = tmpHash.dup()
      apiCaller.setRsrcPath("#{dbUriObj.path}/trks/defaultStyle?")
      apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
      apiCaller.get()
      tmpHash = JSON.parse(apiCaller.respBody())['data']['hash']
      unless(loadDefaults)
        $stderr.puts "load personal styles."
        apiCaller.setRsrcPath("#{dbUriObj.path}/trks/style?")
        apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
        apiCaller.get()
        resp = JSON.parse(apiCaller.respBody())['data']['hash']
        resp.each_key { |key|
          tmpHash[key] = resp[key] if(!resp[key].nil?) 
        }
      end
      tmpHash.each_key { |key|
        tmpHash[key] = 'simple_draw' if(tmpHash[key].nil?)  
      }
      settingsHash[dbUri][:style] = tmpHash.dup()
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
