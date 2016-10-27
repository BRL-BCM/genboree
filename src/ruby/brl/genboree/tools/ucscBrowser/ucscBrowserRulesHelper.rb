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
  class UcscBrowserRulesHelper < WorkbenchRulesHelper

    TOOL_ID = 'ucscBrowser'

    def rulesSatisfied?(wbJobEntity, sectionsToSatisfy=[ :inputs, :outputs, :context, :settings ], toolIdStr=@toolIdStr)
      rulesSatisfied = super(wbJobEntity, sectionsToSatisfy, toolIdStr)
      inputs = wbJobEntity.inputs
      # The user should have write access to all inputs since the big* files will be written to the database the track is in.
      if(rulesSatisfied)
        userId = wbJobEntity.context['userId']
        # All databases must have a gbKey
        dbHash = {}
        trkHash = Hash.new { |hh,kk|
          hh[kk] = {}
        }
        dbVer = nil
        inputs.each { |input|
          dbUri = @dbApiHelper.extractPureUri(input)
          if(!dbHash.has_key?(input))
            dbUriObj = URI.parse(dbUri)
            apiCaller = WrapperApiCaller.new(dbUriObj.host, dbUriObj.path, userId)
            apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
            apiCaller.get()
            retVal = JSON.parse(apiCaller.respBody)['data']
            if(retVal['gbKey'].nil? or retVal['gbKey'].empty?)
              wbJobEntity.context['wbErrorMsg'] = "INVALID_INPUT: One or more of the database(s) are locked. Please unlock all database(s) using the 'Unlock Database' feature before using this tool."
              rulesSatisfied = false
            else
              if(dbVer.nil? or dbVer == retVal['version'])
                dbVer = retVal['version']
                wbJobEntity.settings["gbKey_#{dbUri}"] = retVal['gbKey']
                dbHash[dbUri] = true
              else
                wbJobEntity.context['wbErrorMsg'] = "INVALID_INPUT: All tracks must come from the same reference genome assembly."
                rulesSatisfied = false
              end
            end
          end
        }
        # Prep some settings for the UI
        if(rulesSatisfied)
          wbJobEntity.settings["dbVersion"] = "#{dbVer[0,1].downcase}#{dbVer[1,dbVer.size]}"
          inputs.each { |input|
            dbUri = @dbApiHelper.extractPureUri(input)
            if(@trkApiHelper.extractName(input)) # For tracks
              trkHash[dbUri][@trkApiHelper.extractName(input)] = true
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
                trkHash[dbUri][track['text']] = true
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
                trkHash[dbUri][@trkApiHelper.extractName(track['url'])] = true
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
                trkHash[dbUri][track['name']] = true
              }
            end
          }
          wbJobEntity.settings['trkHash'] = trkHash
          # ------------------------------------------------------------------
          # CHECK SETTINGS
          # ------------------------------------------------------------------
          if(sectionsToSatisfy.include?(:settings))
            # Check :settings together with info from :outputs :
            unless( sectionsToSatisfy.include?(:outputs) and  sectionsToSatisfy.include?(:inputs) )
              raise ArgumentError, "Cannot validate just :settings for this tool without info provided in both :inputs and :outputs."
            end
            rulesSatisfied = false
            # At least one track must be checked
            settings = wbJobEntity.settings
            baseWidget = settings['baseWidget']
            trkChecked = false
            settings.each_key { |key|
              if(key =~ /^#{baseWidget}/)
                if(settings[key] and settings[key] == 'on')
                  trkChecked = true
                  break
                end
              end
            }
            unless(trkChecked)
              wbJobEntity.context['wbErrorMsg'] = "INVALID_INPUT: You must select at least one track to visualize."
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
