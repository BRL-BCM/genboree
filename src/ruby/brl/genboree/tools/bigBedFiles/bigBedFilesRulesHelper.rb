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
  class BigBedFilesRulesHelper < WorkbenchRulesHelper

    TOOL_ID = 'bigBedFiles'

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
            if(input !~ /\/trks\/entityList\//)
              if(!previousDb.nil?)
                if(@dbApiHelper.extractPureUri(input) != previousDb)
                  allDbsSame = false
                  break
                end
              end
              previousDb = @dbApiHelper.extractPureUri(input)
            else
              uriObj = URI.parse(input)
              apiCaller = WrapperApiCaller.new(uriObj.host, uriObj.path, userId)
              apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
              apiCaller.get()
              retVal = JSON.parse(apiCaller.respBody)
              tracks = retVal['data']
              tracks.each { |track|
                if(!previousDb.nil?)
                  if(@dbApiHelper.extractPureUri(track['url']) != previousDb)
                    allDbsSame = false
                    break
                  end
                end
                previousDb = @dbApiHelper.extractPureUri(track['url'])
              }
            end
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
            inputs.each { |input|
              if(@trkApiHelper.extractName(input)) # For tracks
                trkName = @trkApiHelper.extractName(input)
                ftypeHash = ftypesHash[trkName]
                unless(ftypeHash['dbNames'].size > 1 or ftypeHash['dbNames'][0]['dbType'] == :sharedDb)
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
                  trkName = track['text']
                  ftypeHash = ftypesHash[trkName]
                  unless(ftypeHash['dbNames'].size > 1 or ftypeHash['dbNames'][0]['dbType'] == :sharedDb)
                    trkUri = "#{dbUri.chomp("?")}/trk/#{CGI.escape(track['text'])}?"
                    trkHash[trkName] = true
                  end
                }
              elsif(input =~ /trks\/entityList/) # For track entity list
                # For template tracks, set hash value to false: Will NOT be selected by default
                uri = URI.parse(input)
                rcscUri = uri.path
                apiCaller = WrapperApiCaller.new(uri.host, rcscUri, userId)
                apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
                apiCaller.get()
                resp = apiCaller.respBody()
                retVal = JSON.parse(resp)
                tracks = retVal['data']
                tracks.each { |track|
                  trkName = @trkApiHelper.extractName(track['url'])
                  ftypeHash = ftypesHash[trkName]
                  unless(ftypeHash['dbNames'].size > 1 or ftypeHash['dbNames'][0]['dbType'] == :sharedDb)
                    trkHash[trkName] = true
                  end
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
                  ftypeHash = ftypesHash[trkName]
                  unless(ftypeHash['dbNames'].size > 1 or ftypeHash['dbNames'][0]['dbType'] == :sharedDb)
                    trkHash[trkName] = true
                  end
                }
              end
            }
            wbJobEntity.settings['trkHash'] = trkHash
          end
        end
        if(sectionsToSatisfy.include?(:settings))
          # Check :settings together with info from :outputs :
          unless( sectionsToSatisfy.include?(:outputs) and  sectionsToSatisfy.include?(:inputs) )
            raise ArgumentError, "Cannot validate just :settings for this tool without info provided in both :inputs and :outputs."
          end
          rulesSatisfied = false
          # At least one track should be selected
          settings = wbJobEntity.settings
          trkSelected = false
          baseWidget = settings['baseWidget']
          settings.each_key { |key|
            if(key =~ /^#{baseWidget}/)
              trkSelected = true
              break
            end
          }
          if(!trkSelected)
            wbJobEntity.context['wbErrorMsg'] = "INVALID_INPUTS: You must select at least one track."
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
