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
  class RenameTracksRulesHelper < WorkbenchRulesHelper
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
          # Check :settings together with info from :outputs :
          unless( sectionsToSatisfy.include?(:outputs) and  sectionsToSatisfy.include?(:inputs) )
            raise ArgumentError, "Cannot validate just :settings for this tool without info provided in both :inputs and :outputs."
          end
          settings = wbJobEntity.settings
          # There should be no repeats in the new values of the track names.
          # All type an subtype values should be non empty
          badNameTracks = []
          trkValHash = {}
          dupNames = {}
          trksToUpdate = {}
          origTrkNames = {}
          trkHash.each_key { |key|
            if(settings.key?("trkArray|#{key}|type") and settings.key?("trkArray|#{key}|subtype"))
              if(trkValHash.key?("#{settings["trkArray|#{key}|type"]}:#{settings["trkArray|#{key}|subtype"]}"))
                trkValHash["#{settings["trkArray|#{key}|type"]}:#{settings["trkArray|#{key}|subtype"]}"] << key
              else
                trkValHash["#{settings["trkArray|#{key}|type"]}:#{settings["trkArray|#{key}|subtype"]}"] = [key]
              end
              badNameTracks << key if(settings["trkArray|#{key}|type"].empty? or settings["trkArray|#{key}|subtype"].empty? or settings["trkArray|#{key}|type"] =~ /:/ or settings["trkArray|#{key}|subtype"] =~ /:/)
              if(ftypesHash.key?("#{settings["trkArray|#{key}|type"]}:#{settings["trkArray|#{key}|subtype"]}") and key != "#{settings["trkArray|#{key}|type"]}:#{settings["trkArray|#{key}|subtype"]}")
                dupNames[key] = "#{settings["trkArray|#{key}|type"]}:#{settings["trkArray|#{key}|subtype"]}" 
              else
                trksToUpdate[ftypesHash[key]['ftypeid']] = "#{settings["trkArray|#{key}|type"]}:#{settings["trkArray|#{key}|subtype"]}" if(key != "#{settings["trkArray|#{key}|type"]}:#{settings["trkArray|#{key}|subtype"]}")
                origTrkNames[ftypesHash[key]['ftypeid']] = key
              end
            end
          }
          repeatedNames = ""
          trkValHash.each_key { |key|
            if(trkValHash[key].size > 1)
              type = key.split(":")[0]
              subtype = key.split(":")[1]
              repeatedNames << "You have entered the same Type: '#{type}' and Subtype: '#{subtype}' for the following tracks:"
              repeatedNames << "<ul>"
              trkValHash[key].each { |trk|
                repeatedNames << "<li>#{trk}</li>"
              }
              repeatedNames << "</ul>"
            end
          }
          if(!repeatedNames.empty?)
            wbJobEntity.context['wbErrorMsg'] = "DUPLICATE_VALUES:</br>#{repeatedNames}"
            wbJobEntity.context['wbErrorMsgHasHtml'] = true
            rulesSatisfied = false
          else
            if(!badNameTracks.empty?)
              errMsg = "BAD_VALUES: The following track(s) have either empty type/subtype values or have a ':'<ul>"
              wbJobEntity.context['wbErrorMsgHasHtml'] = true
              badNameTracks.each { |trk|
                errMsg << "<li>#{trk}</li>"  
              }
              errMsg << "</ul>"
              wbJobEntity.context['wbErrorMsg'] = errMsg
              rulesSatisfied = false
            else
              if(!dupNames.empty?)
                errMsg = "DUPLICATE_VALUES:<ul>"
                wbJobEntity.context['wbErrorMsgHasHtml'] = true
                dupNames.each_key { |trk|
                  errMsg << "<li>Cannot rename #{trk} to #{dupNames[trk]} (#{dupNames[trk]} already exists)</li>"  
                }
                errMsg << "</ul>"
                wbJobEntity.context['wbErrorMsg'] = errMsg
                rulesSatisfied = false
              else
                if(!trksToUpdate.empty?)
                  wbJobEntity.settings['trksToUpdate'] = trksToUpdate
                  wbJobEntity.settings['origTrkNames'] = origTrkNames
                else
                  wbJobEntity.context['wbErrorMsg'] = "NO_TRKS: You need to rename at least one track to launch the job."
                  rulesSatisfied = false
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
