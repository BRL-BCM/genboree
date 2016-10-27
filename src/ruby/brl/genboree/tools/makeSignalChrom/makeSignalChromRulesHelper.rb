require 'brl/genboree/tools/workbenchRulesHelper'
require 'brl/genboree/tools/workbenchFormHelper'
require 'brl/genboree/rest/helpers/trackApiUriHelper'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require 'brl/genboree/rest/helpers/classApiUriHelper'
require 'brl/genboree/rest/helpers/trackEntityListApiUriHelper'
require 'uri'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/rest/apiCaller'
include BRL::Genboree::REST

module BRL ; module Genboree ; module Tools
  class MakeSignalChromRulesHelper < WorkbenchRulesHelper

    TOOL_ID = 'makeSignalChrom'

    def rulesSatisfied?(wbJobEntity, sectionsToSatisfy=[ :inputs, :outputs, :context, :settings ], toolIdStr=@toolIdStr)
      # Apply basic rules from the rules file (counts, basic types, other simple things)
      rulesSatisfied = super(wbJobEntity, sectionsToSatisfy, toolIdStr)
      if(rulesSatisfied)
        @dbu = BRL::Genboree::DBUtil.new("#{@genbConf.dbrcKey}", nil, nil)
        # Must pass the rest of the checks as well
        rulesSatisfied = false
        outputs = wbJobEntity.outputs
        @inputs = wbJobEntity.inputs


        # ------------------------------------------------------------------
        # Check Inputs/Outputs
        # ------------------------------------------------------------------
        @userId = wbJobEntity.context['userId']
        @hostAuthMap = Abstraction::User.getHostAuthMapForUserId(@dbu, @userId)
        # Check 1: are all the input files from the same db version?
        unless(checkDbVersions(@inputs + outputs, skipNonDbUris=true)) # Failed
          wbJobEntity.context['wbErrorMsg'] = "Database version of one or more input file(s) do not match target database."
        else
          rulesSatisfied = true
    
          # Get the target database Uri. Ouptut targets can have a db and a project resource
          if(wbJobEntity.outputs[0] !~ (BRL::Genboree::REST::Helpers::DatabaseApiUriHelper::NAME_EXTRACTOR_REGEXP))
            outputDb = wbJobEntity.outputs[1]
          else
            outputDb = wbJobEntity.outputs[0]
          end          
          # Get the genome version
          targetDbUriObj = URI.parse(outputDb)
          apiCaller = ApiCaller.new(targetDbUriObj.host, "#{targetDbUriObj.path}?", @hostAuthMap)
          apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
          apiCaller.get()
          resp = JSON.parse(apiCaller.respBody)['data']
          genomeVersion = resp['version'].decapitalize
          wbJobEntity.settings['assembly'] = genomeVersion
          #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "GENOMEVERSION?: #{genomeVersion.inspect}")


          # Get the trackHash
          trkHash = {}
          dbApiHelper = BRL::Genboree::REST::Helpers::DatabaseApiUriHelper.new()
          @pureDbUris = {}
         
          @inputs.each { |input|
            dburi = @dbApiHelper.extractPureUri(input.chomp('?'))
            @pureDbUris[dburi] = {}
            if(input =~ BRL::Genboree::REST::Helpers::TrackApiUriHelper::NAME_EXTRACTOR_REGEXP)#For tracks
              trkHash[input] = true
            elsif(input =~ BRL::Genboree::REST::Helpers::TrackEntityListApiUriHelper::NAME_EXTRACTOR_REGEXP) # For track Entity Lists
              inputObj = URI.parse(input)
              apiCaller = WrapperApiCaller.new(inputObj.host, inputObj.path, @userId)
              apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
              apiCaller.get()
              if(apiCaller.succeeded?)
                resp = apiCaller.parseRespBody['data']
                resp.each{ |trk|
                trkHash[trk['url']] = true
              }
              else
                wbJobEntity.context['wbErrorMsg'] = " MISSING_RESOURCE: ApiCaller failed for getting tracks for the trackEntityList: #{@trkListApiHelper.extractName(input)}."
                rulesSatisfied = false
              end
            
            elsif(@classApiHelper.extractName(input)) # class
              className = @classApiHelper.extractName(input)
              dbUri = @dbApiHelper.extractPureUri(input)
              uri = dbUri.dup()
              uri = URI.parse(uri)
              rcscUri = uri.path.chomp("?")
              rcscUri << "/trks?connect=false&class=#{CGI.escape(className)}"
              apiCaller = WrapperApiCaller.new(uri.host, rcscUri, @userId)
              apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
              apiCaller.get()
              if(!apiCaller.succeeded?)
                wbJobEntity.context['wbErrorMsg'] = "MISSING_RESOURCE: ApiCaller failed for getting tracks for class: #{className.inspect}. "
                rulesSatisfied = false
              end
              resp = apiCaller.respBody()
              retVal = JSON.parse(resp)
              tracks = retVal['data']
              tracks.each { |track|
                trkUri = "#{dbUri.chomp("?")}/trk/#{CGI.escape(track['text'])}?"
                trkHash[trkUri] = true
              }
            else #db
              uri = URI.parse(input)
              rcscPath = uri.path
              apiCaller = WrapperApiCaller.new(uri.host, "#{rcscPath}/trks?detailed=minDetails", @userId)
              apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
              apiCaller.get()
              resp = apiCaller.respBody()
              retVal = JSON.parse(resp)
              tracks = retVal['data']
              tracks.each { |track|
                trkUri = "#{dburi.chomp("?")}/trk/#{CGI.escape(track['name'])}?"
                trkHash[trkUri] = true
              }
            end
          }
          
          #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "TRACKHASH?: #{trkHash.inspect}")

          # Grid Variables   
          # Four track attributes 
          @gridFields = ['name', 'chromHMMCell', 'chromHMMMark', 'chromHMMControl']
          @gridRecs = Array.new()
          @gridRowUriMap = Array.new()
      
          #get track attributes for setting grid related variables
          trackAttrFetched =  getTrackAttributes()
          unless(trackAttrFetched)
            wbJobEntity.context['wbErrorMsg'] = "ApiCaller failed to retreive track attributes. "
            rulesSatisfied = false
          end

          # sort the trackHash keys
          sortedTrk = Array.new()
          sortedTrk = trkHash.keys.sort()
          sortedTrk.each { |trackUri|
            @gridRowUriMap << trackUri.chomp('?')
            tmpList = Array.new()
            trkName = @trkApiHelper.extractName(trackUri)
            tmpList << trkName
            puredb = @dbApiHelper.extractPureUri(trackUri.chomp('?'))
            @gridFields[1..4].each {|field|
              if(@pureDbUris[puredb]['data'][trkName].key?(field))
                tmpList << @pureDbUris[puredb]['data'][trkName][field]
              else
                if(field == "chromHMMControl")
                  tmpList << "no"
                else
                  tmpList << ""
                end
              end
            }
            @gridRecs << tmpList
          }
   
          @trackAttributes = {} # This hash groups the tracks by sampleName(chromHMMCell)
           @gridRowUriMap.each_with_index {|rowtrk, index|
            sampleID = ""
            sampleID = @gridRecs[index][1]
            sampleID = "empty" if(sampleID.nil? or sampleID.empty?)
            if(@trackAttributes.key?(sampleID))
              @trackAttributes[sampleID][rowtrk] = {}
              @trackAttributes[sampleID][rowtrk]["chromHMMMark"] = @gridRecs[index][2]
              @trackAttributes[sampleID][rowtrk]["chromHMMControl"] = @gridRecs[index][3]
            else
              @trackAttributes[sampleID] = {}
              @trackAttributes[sampleID][rowtrk] = {}
              @trackAttributes[sampleID][rowtrk]["chromHMMMark"] = @gridRecs[index][2]
              @trackAttributes[sampleID][rowtrk]["chromHMMControl"] = @gridRecs[index][3]
            end
          }
          wbJobEntity.settings['gridRowUriMap'] = @gridRowUriMap.to_json
          wbJobEntity.settings['gridRecs'] = @gridRecs.to_json
          wbJobEntity.settings['gridFields'] = @gridFields.to_json
          #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "Sttings?: #{wbJobEntity.settings.inspect}")

        end
        # CHECK SETTINGS
        # ------------------------------------------------------------------
        if(sectionsToSatisfy.include?(:settings))
          # Check :settings together with info from :outputs :
          unless( sectionsToSatisfy.include?(:outputs) and  sectionsToSatisfy.include?(:inputs) )
            raise ArgumentError, "Cannot validate just :settings for this tool without info provided in both :inputs and :outputs."
          end
          rulesSatisfied = true
          # Check1: A job with the same analysis name under the same target db should not exist
          output = @dbApiHelper.extractPureUri(outputDb)
          uri = URI.parse(output)
          host = uri.host
          rcscUri = uri.path
          rcscUri = rcscUri.chomp("?")
          rcscUri << "/file/FindERChromHMM%20-%20Results/#{CGI.escape(wbJobEntity.settings['analysisName'])}/jobFile.json?"
          apiCaller = ApiCaller.new(host, rcscUri, @hostAuthMap)
          apiCaller.initInternalRequest(@rackEnv, genbConf.machineNameAlias) if(@rackEnv)
          apiCaller.get()
          if(apiCaller.succeeded?) # Failed: job dir already exists
            wbJobEntity.context['wbErrorMsg'] = "A job with the analysis name: #{wbJobEntity.settings['analysisName']} has already been launched before. Please select a different job name."
            rulesSatisfied = false 
          else
            rulesSatisfied = true
            settings = wbJobEntity.settings
            states = settings['states']
            trkEditHash = settings['sampleEditHash']
            sampleAttributeRemoveHash = settings['sampleAttributeRemoveHash']
            sampleRowUriMap = settings['sampleRowUriMap']
            sampleNameDataMap = settings['sampleNameDataMap']
            selectedRowIndices = settings['selectedtrks']
            
            #get the selected trackUri and pass it to inputs
            selectedtracks = Array.new()
            selectedRowIndices.each {|index|
              selectedtracks << @gridRowUriMap[index]
            }
            # Check2: Reject if no tracks are selected
            if(selectedtracks.empty?)
             wbJobEntity.context['wbErrorMsg'] = "NO TRACKS SELECTED: No rows selected. Select rows/tracks to run the job. Please select rows/tracks and resubmit the job."
             rulesSatisfied = false
            else
              wbJobEntity.inputs = selectedtracks
            end
            
            # get the edits from the grid
             changedSamples = {}
             trkEditHash.each_key {|rowedited|
               tmpsample = ""
               if(trkEditHash[rowedited].key?("chromHMMCell"))
                 tmpsample = trkEditHash[rowedited]["chromHMMCell"]
                 oldsample = @gridRecs[rowedited.to_i][1]
                 oldsample = "empty" if (oldsample.nil? or oldsample.empty?)
                 changedSamples[oldsample] = tmpsample
                 if(@trackAttributes.key?(tmpsample))
                   @trackAttributes[tmpsample] = @trackAttributes[tmpsample].merge(@trackAttributes[oldsample])
                 else
                   @trackAttributes[tmpsample] = {}
                   @trackAttributes[tmpsample] = @trackAttributes[oldsample]
                 end
               # remove the oldsample
               @trackAttributes.delete(oldsample)
               end
               trkEditHash[rowedited].keys.each{ |key|
               if(key != "chromHMMCell")
                 @trackAttributes.each_key {|sample|
                   if(@trackAttributes[sample].key?(sampleRowUriMap[rowedited]))
                     @trackAttributes[sample][sampleRowUriMap[rowedited]][key] = trkEditHash[rowedited][key]
                   end
                 }
               end
              }
             }

             # get the selected track info
             @filteredtrackAttributes = {}
             selectedtracks.each {|track|
               @trackAttributes.each_key{|sample|
                 if(@trackAttributes[sample].key?(track))
                   if(@filteredtrackAttributes.key?(sample))
                     @filteredtrackAttributes[sample][track] =  @trackAttributes[sample][track]
                   else
                     @filteredtrackAttributes[sample] = {}
                     @filteredtrackAttributes[sample][track] =  @trackAttributes[sample][track]
                   end
                   # Check 3: ChromHMMMark cannot be left empty
                   if(@filteredtrackAttributes[sample][track]['chromHMMMark'].empty?)
                       wbJobEntity.context['wbErrorMsg'] = "Track attribute chromHMMMark is empty or is missing for the track #{@trkApiHelper.extractName(track)}."
                       rulesSatisfied = false
                   end
                 end
               }
             }
             # Check: for the number of tracks in each sample
             # Number of states must be less than 2**{Num Tracks selected} for each sample
             @filteredtrackAttributes.each_key {|sample|
               controlCount = 0
               tmpsize = @filteredtrackAttributes[sample].size()
               #get the control chosen - must be exactly one per sample
               @filteredtrackAttributes[sample].each_key{|track|
                 if(@filteredtrackAttributes[sample][track]['chromHMMControl'] == 'yes')
                   controlCount += 1
                 end
               }
               # Check: for control. Not more than one control per sample is allowe
               $stderr.debugPuts(__FILE__, __method__, "DEBUG", "ControlCount?: #{controlCount}")
               $stderr.debugPuts(__FILE__, __method__, "DEBUG", "TMPSIZE?: #{tmpsize.inspect}")
               if(controlCount == 1)
                 if(tmpsize == 1)
                   wbJobEntity.context['wbErrorMsg'] = "INVALID_SELECTION: No regular tracks and only one control track is present for the sample #{sample}. At least one regular track should be present besides the control track."
                   rulesSatisfied = false
                   break
                 end
                 if(states.to_i > 2**(tmpsize-1))
                   wbJobEntity.context['wbErrorMsg'] = "INVALID_SETTINGS: Number of states MUST be less than or equal to 2**{NUM_TRACKS/NUM_MARKS} per SAMPLE excluding the control track. You selected NUMBER OF TRACKS: #{tmpsize} for the sample: #{sample}, and STATES: #{states}."
                   rulesSatisfied = false
                   break
                 end
               elsif(controlCount == 0)
                 if(states.to_i > 2**(tmpsize))
                   wbJobEntity.context['wbErrorMsg'] = "INVALID_SETTINGS: Number of states MUST be less than or equal to 2**{NUM_TRACKS/NUM_MARKS} per SAMPLE excluding the control track. You selected NUMBER OF TRACKS: #{tmpsize} for the sample: #{sample}, and STATES: #{states}."
                   rulesSatisfied = false
                   break
                 end
               else# more than one control
                 wbJobEntity.context['wbErrorMsg'] = "INVALID_INPUT: Number of controls for the sample, #{sample} are #{controlCount}. Only one control ia allowed per sample."
                 rulesSatisfied = false
                 break
               end
             }
             wbJobEntity.settings['trkAttributes'] = @filteredtrackAttributes
             #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "Settings?: #{wbJobEntity.settings.inspect}")
             
          end #apiCaller.succeeded?
        end #sectionsToSatisfy.include?
      end #rulesSatisfied
      return rulesSatisfied
    end


    #Get all the three attributes 
    # Return a list with the values of the three attributes
    def getTrackAttributes()
      attList = ['chromHMMCell', 'chromHMMMark', 'chromHMMControl']
      success = true
      @pureDbUris.each_key {|databaseuri|
        dburi = URI.parse(databaseuri)
        host = dburi.host
        apiCaller = ApiCaller.new(host, "", @hostAuthMap)
        rsUri = "#{dburi.path}/trks/attributes/map?attributeList=#{attList.join(',')}"
        apiCaller.setRsrcPath(rsUri)
        apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
        apiCaller.get()
        if(apiCaller.succeeded?)
          @pureDbUris[databaseuri]['data'] = apiCaller.parseRespBody['data']
        else
          success = false
        end
      }
      return success
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
