require 'brl/genboree/tools/workbenchRulesHelper'
require 'brl/genboree/tools/workbenchFormHelper'
require 'brl/genboree/rest/helpers/trackApiUriHelper'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require 'brl/genboree/rest/helpers/fileApiUriHelper'
require 'brl/genboree/abstract/resources/jobFile'
require 'uri'
require 'brl/genboree/rest/apiCaller'
include BRL::Genboree::REST

module BRL ; module Genboree ; module Tools
  class ComparativeSignalSimilaritySearchRulesHelper < WorkbenchRulesHelper
    TOOL_LABEL = :hidden
    def rulesSatisfied?(wbJobEntity, sectionsToSatisfy=[ :inputs, :outputs, :context, :settings ], toolIdStr=@toolIdStr)
      # Apply basic rules from the rules file (counts, basic types, other simple things)
      rulesSatisfied = super(wbJobEntity, sectionsToSatisfy, toolIdStr)

      if(rulesSatisfied)
        @dbu = BRL::Genboree::DBUtil.new("#{@genbConf.dbrcKey}", nil, nil)
        # Must pass the rest of the checks as well
        rulesSatisfied = false
        # ------------------------------------------------------------------
        # Check Inputs/Outpus
        # ------------------------------------------------------------------
        if(sectionsToSatisfy.include?(:inputs) or sectionsToSatisfy.include?(:outputs))
          # Check :inputs & :outputs together:
          if( (sectionsToSatisfy.include?(:inputs) and !sectionsToSatisfy.include?(:outputs)) or
              (sectionsToSatisfy.include?(:outputs) and !sectionsToSatisfy.include?(:inputs)))
              raise ArgumentError, "Cannot validate just :inputs or just :outputs, only both together."
          end
          inputs = wbJobEntity.inputs
          outputs = wbJobEntity.outputs
          # Check 0: See if there is a folder
          folderPresent = false
          inputs.each { |input|
            if(input !~ BRL::Genboree::REST::Helpers::TrackApiUriHelper::NAME_EXTRACTOR_REGEXP)
              folderPresent = true
            end
          }
          # Check 1: does user have write permission to the first db?
          userId = wbJobEntity.context['userId']
          unless(@dbApiHelper.accessibleByUser?(outputs.first, userId, CAN_WRITE_CODES))
            # FAILED: doesn't have write access to output database
            wbJobEntity.context['wbErrorMsg'] =
            {
              :msg => "You don't have permission to write to the first output database.",
              :type => :writeableDbs,
              :info => @dbApiHelper.accessibleDatabasesHash(outputs, userId, CAN_WRITE_CODES)
            }
          else # OK: user can write to the first output database
            # Check 2: If 2 output dbs check if user has permission to write to the second db
            permission = true
            if(outputs.size == 2)
              unless(@dbApiHelper.accessibleByUser?(outputs[1], userId, CAN_WRITE_CODES))
                permission = false
              end
            end
            # Failed: user does not have permission for the second db
            unless(permission)
              # FAILED: doesn't have write access to output database
              wbJobEntity.context['wbErrorMsg'] =
              {
                :msg => "You don't have permission to write to the second output database.",
                :type => :writeableDbs,
                :info => @dbApiHelper.accessibleDatabasesHash(outputs, userId, CAN_WRITE_CODES)
              }
            else
              # Check 3: If a folder is dragged, we need to check if it was generated by the ROI-Lifter tool
              jobFilePresent = true
              depTrackOrder = nil
              folderOrder = nil
              lifterOutputs = nil
              if(folderPresent)
                folder = nil
                folderOrder = 0
                inputs.each { |input|
                  if(input !~ BRL::Genboree::REST::Helpers::TrackApiUriHelper::NAME_EXTRACTOR_REGEXP)
                    folder = input
                    break
                  end
                  folderOrder += 1
                }
                if(folderOrder == 0)
                  depTrackOrder = 1
                else
                  depTrackOrder = 0
                end
                jobFileUri = "#{folder.chomp("?")}/jobFile.json"
                begin
                  jobFileObj = BRL::Genboree::Abstract::Resources::JobFile.new(jobFileUri, @rackEnv)
                  jobFileObj.parseJobFile()
                  toolName = jobFileObj.context['toolIdStr']
                  if(toolName != 'compEpigenomicsROILifter')
                    jobFilePresent = false
                  else
                    lifterOutputs = jobFileObj.outputs
                  end
                rescue => err
                  $stderr.puts err
                  jobFilePresent = false
                end
              end
              unless(jobFilePresent) # Failed.
                wbJobEntity.context['wbErrorMsg'] = "INVALID_INPUT: The input folder MUST be the output folder generated by the 'Comparative Epigenomics - ROI-Lifter' tool."
              else
                # Check 4:  The version of ROI Track must be the same as that of the score track(s)
                correctOrder = true
                errorMsg = ''
                if(!folderPresent) # All tracks, no folder
                  # For the 'indepenedent' track set, we need to loop over all score tracks and compare the version with the ROI Track
                  targetROIVersion = @dbApiHelper.dbVersion(inputs[2])
                  inputs.size.times { |ii|
                    next if(ii == 0 or ii == 1 or ii == 2)
                    correctOrder = false if(@dbApiHelper.dbVersion(inputs[ii]) != targetROIVersion)
                  }
                  if((@dbApiHelper.dbVersion(inputs[0]) != @dbApiHelper.dbVersion(inputs[1])) or (!correctOrder)) # Failed
                    correctOrder = false
                    errorMsg = 'INVALID_INPUT: The order of input tracks is incorrect. The database version of the ROI track MUST match the version of the score track(s).'
                  end
                else # Folder present
                  # First make sure that all independent score tracks have the same version
                  indepScoreVersion = nil
                  inputs.size.times { |ii|
                    next if(ii == depTrackOrder or inputs[ii] !~ BRL::Genboree::REST::Helpers::TrackApiUriHelper::NAME_EXTRACTOR_REGEXP)
                    if(!indepScoreVersion)
                      indepScoreVersion = @dbApiHelper.dbVersion(inputs[ii])
                    else
                      if(indepScoreVersion != @dbApiHelper.dbVersion(inputs[ii]))
                        correctOrder = false
                        break
                      end
                    end
                  }
                  # At this stage correctOrder will be true only if All independent score tracks have same version.
                  # If its true compare the version with the ROI Track coming from job file in the folder
                  if(correctOrder)
                    correctOrder = false if(@dbApiHelper.dbVersion(lifterOutputs[0]) != indepScoreVersion and @dbApiHelper.dbVersion(lifterOutputs[1]) != indepScoreVersion)
                  end
                  if(@dbApiHelper.dbVersion(inputs[depTrackOrder]) != @dbApiHelper.dbVersion(lifterOutputs[0]) and @dbApiHelper.dbVersion(inputs[depTrackOrder]) != @dbApiHelper.dbVersion(lifterOutputs[1]) or !correctOrder)
                    correctOrder = false
                    errorMsg = "INVALID_INPUT: The database versions of the ROI Tracks from the ROI-Lifter job MUST match the score tracks. "
                  end
                end
                unless(correctOrder)
                  wbJobEntity.context['wbErrorMsg'] = errorMsg
                else
                  # Check 5: The versions of the two ROI Tracks should not match
                  sameDbVer = false
                  if(!folderPresent)
                    sameDbVer = true if(@dbApiHelper.dbVersion(inputs[0]) == @dbApiHelper.dbVersion(inputs[2]))
                  else
                    sameDbVer = true if(@dbApiHelper.dbVersion(lifterOutputs[0]) == @dbApiHelper.dbVersion(lifterOutputs[1])) # This should not happen since the validation of the ROI-Lifter tool should catch this.
                  end
                  if(sameDbVer)
                    wbJobEntity.context['wbErrorMsg'] = "INVALID_INPUT: The database versions of the two ROI tracks MUST be different."
                  else
                    # Check 6: The score tracks MUST be high density
                    scoreTrackHighDens = true
                    indepScoreTracksHighDens = true
                    if(!folderPresent)
                      inputs.size.times { |ii|
                        next if(ii == 0 or ii == 1 or ii == 2)
                        if(!@trkApiHelper.isHdhv?(inputs[ii]))
                          indepScoreTracksHighDens = false
                          break
                        end
                      }
                      scoreTrackHighDens = false if(!@trkApiHelper.isHdhv?(inputs[1]) or !indepScoreTracksHighDens)
                    else
                      inputs.size.times { |ii|
                        next if(ii == depTrackOrder or inputs[ii] !~ BRL::Genboree::REST::Helpers::TrackApiUriHelper::NAME_EXTRACTOR_REGEXP)
                        if(!@trkApiHelper.isHdhv?(inputs[ii]))
                          indepScoreTracksHighDens = false
                          break
                        end
                      }
                      scoreTrackHighDens = false if(!@trkApiHelper.isHdhv?(inputs[depTrackOrder]) or !indepScoreTracksHighDens)
                    end
                    unless(scoreTrackHighDens) #Failed
                      wbJobEntity.context['wbErrorMsg'] = "INVALID_INPUT: The score track(s) MUST be High Density High Volume (HDHV) tracks. "
                    else
                      # Check 7: The ROI Tracks should NOT be hdhv tracks
                      roiHdhv = false
                      if(!folderPresent)
                        roiHdhv = true if(@trkApiHelper.isHdhv?(inputs[0]) or @trkApiHelper.isHdhv?(inputs[2]))
                      else
                        roiHdhv = true if(@trkApiHelper.isHdhv?(lifterOutputs[0]) or @trkApiHelper.isHdhv?(lifterOutputs[1]))
                      end
                      if(roiHdhv)
                        wbJobEntity.context['wbErrorMsg'] = "INVALID_INPUT: The Regions of Interest (ROI) tracks MUST NOT be High Density High Volume (HDHV) tracks. "
                      else
                        outputsSize = outputs.size
                        # Check 8: If there are 2 target dbs, they MUST have different versions
                        if(outputsSize == 2 and (@dbApiHelper.dbVersion(outputs[0]) == @dbApiHelper.dbVersion(outputs[1])))
                          wbJobEntity.context['wbErrorMsg'] = "INVALID_INPUT: The two target databases MUST have different database versions. "
                        else
                          # Check 9: If there are 2 target dbs, one of them must match one set (ROI & score) of the input tracks and the other must match the other set
                          outputMatch = true
                          if(outputsSize == 2)
                            if(!folderPresent)
                              outputMatch = false if((@dbApiHelper.dbVersion(outputs[0]) != @dbApiHelper.dbVersion(inputs[0]) and @dbApiHelper.dbVersion(outputs[0]) != @dbApiHelper.dbVersion(inputs[2])) or
                                                     (@dbApiHelper.dbVersion(outputs[1]) != @dbApiHelper.dbVersion(inputs[0]) and @dbApiHelper.dbVersion(outputs[1]) != @dbApiHelper.dbVersion(inputs[2])))
                            else
                              outputMatch = false if((@dbApiHelper.dbVersion(outputs[0]) != @dbApiHelper.dbVersion(lifterOutputs[0]) and @dbApiHelper.dbVersion(outputs[0]) != @dbApiHelper.dbVersion(lifterOutputs[1])) or
                                                     (@dbApiHelper.dbVersion(outputs[1]) != @dbApiHelper.dbVersion(lifterOutputs[0]) and @dbApiHelper.dbVersion(outputs[1]) != @dbApiHelper.dbVersion(lifterOutputs[1])))
                            end
                          end
                          unless(outputMatch)
                            wbJobEntity.context['wbErrorMsg'] = "INVALID_INPUT: The database versions of the target databases MUST match the two sets of ROI and score tracks, i.e, one target database MUST match one set of ROI and score track and the other target database MUST match the other set.  "
                          else
                            # Check 10: If there is one target database, the dependent track set must match the version of the target
                            dependentMatch = false
                            if(outputsSize == 1)
                              if(!folderPresent)
                                dependentMatch = true if(@dbApiHelper.dbVersion(outputs[0]) == @dbApiHelper.dbVersion(inputs[1]))
                              else
                                if(@dbApiHelper.dbVersion(outputs[0]) == @dbApiHelper.dbVersion(inputs[depTrackOrder]))
                                  dependentMatch = true
                                end
                              end
                            else
                              dependentMatch = true
                            end
                            unless(dependentMatch)
                              wbJobEntity.context['wbErrorMsg'] = "INVALID_INPUT: The version of the target database MUST match the version of the 'dependent' ROI Track. "
                            else
                               # If we have a folder we need to overwrite wbJobEntity.inputs. We don't want to do this in the .rhtml for the sake of keeping the 'view' clean.
                              if(folderPresent)
                                trackName = CGI.escape("#{jobFileObj.settings['lffType']}:#{jobFileObj.settings['lffSubType']}")
                                newInputs = []
                                if(@dbApiHelper.dbVersion(lifterOutputs[0]) == @dbApiHelper.dbVersion(inputs[depTrackOrder]))
                                  tempUri = lifterOutputs[0].chomp("?")
                                  newInputs.push("#{tempUri}/trk/#{trackName}?")
                                  newInputs.push(inputs[depTrackOrder])
                                  newInputs.push("#{lifterOutputs[1].chomp("?")}/trk/#{trackName}?")
                                else
                                  tempUri = lifterOutputs[1].chomp("?")
                                  newInputs.push("#{tempUri}/trk/#{trackName}?")
                                  newInputs.push(inputs[depTrackOrder])
                                  newInputs.push("#{lifterOutputs[0].chomp("?")}/trk/#{trackName}")
                                end
                                # Add the independent score tracks
                                inputs.size.times { |ii|
                                  next if(ii == depTrackOrder or inputs[ii] !~ BRL::Genboree::REST::Helpers::TrackApiUriHelper::NAME_EXTRACTOR_REGEXP)
                                  newInputs.push(inputs[ii])
                                }
                                wbJobEntity.inputs = newInputs
                              end
                              rulesSatisfied = true
                            end
                          end
                        end
                      end
                    end
                  end
                end
              end
            end
          end
        end

        # ------------------------------------------------------------------
        # CHECK SETTINGS
        # ------------------------------------------------------------------
        if(sectionsToSatisfy.include?(:settings))
          # Check :settings together with info from :outputs :
          unless( sectionsToSatisfy.include?(:outputs) and  sectionsToSatisfy.include?(:inputs) )
            raise ArgumentError, "Cannot validate just :settings for this tool without info provided in both :inputs and :outputs."
          end

          rulesSatisfied = false
          inputs = wbJobEntity.inputs
          outputs = wbJobEntity.outputs
          # Check 1: check if a folder with the analysis name already exists
          genbConf = BRL::Genboree::GenboreeConfig.load()
          dbrcFile = File.expand_path(ENV['DBRC_FILE'])
          user = @superuserApiDbrc.user
          pass = @superuserApiDbrc.password
          jobFolderPresent = false
          studyName = CGI.escape(wbJobEntity.settings['studyName'])
          analysisName = CGI.escape(wbJobEntity.settings['analysisName'])
          parentDir = CGI.escape("Comparative Epigenomics")
          outputs.each { |output|
            if(@dbApiHelper.dbVersion(output) == @dbApiHelper.dbVersion(inputs[0])) # inputs[0] is always 'dependent' at this point
              # Create a folder for this tool named by the analysisName under the Files/ area of thw workbench
              uri = URI.parse(output)
              group = @grpApiHelper.extractName(output)
              db = @dbApiHelper.extractName(output)
              apiCaller = ApiCaller.new(uri.host, "/REST/v1/grp/#{CGI.escape(group)}/db/#{CGI.escape(db)}/file/#{parentDir}/#{studyName}/Signal-Search/#{analysisName}/jobFile.json", user, pass)
              apiCaller.initInternalRequest(@rackEnv, genbConf.machineNameAlias) if(@rackEnv)
              apiCaller.get()
              jobFolderPresent = true if(apiCaller.succeeded?)
            end
          }
          if(jobFolderPresent)
            wbJobEntity.context['wbErrorMsg'] = "INVALID_INPUT: A folder with the analysis name: #{analysisName.inspect} already exists. Please choose a different analysis name."
          else
            rulesSatisfied = true
          end

        end
      end

      # Clean up helpers, which cache many things
      @trkApiHelper.clear() if(!@trkApiHelper.nil?)
      @dbApiHelper.clear() if(!@dbApiHelper.nil?)

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
      else # Look for warnings
        @dbu = BRL::Genboree::DBUtil.new("#{@genbConf.dbrcKey}", nil, nil)
        trackExists = false
        # Get track name
        outTrackType = wbJobEntity.settings['lffType'].to_s.strip
        outTrackSubType = wbJobEntity.settings['lffSubType'].to_s.strip
        outTrkName = "#{outTrackType}:#{outTrackSubType}"
        wbJobEntity.outputs.each { |outputDbUri|
          outputDbName = @dbApiHelper.extractName(outputDbUri)
          # Make output track uri
          outTrkUri = "#{@dbApiHelper.extractPureUri(outputDbUri)}/trk/#{CGI.escape(outTrkName)}"
          # CHECK: Does a non-empty output track with the same name already exist in the destination database?
          uploadFile = wbJobEntity.settings['uploadFile'] ? true : false
          if(!@trkApiHelper.empty?(outTrkUri) and uploadFile)
            # WARNING: output track exists and is not empty
            trackExists = true
            break
          end
        }
        if(trackExists)
          wbJobEntity.context['wbErrorMsg'] = "The track: '#{outTrkName}' already exists in the output database(s). The output of this job will be appended to existing data in the track."
        else
          warningsExist = false
        end
      end

      # Clean up helpers, which cache many things
      @trkApiHelper.clear() if(!@trkApiHelper.nil?)
      @dbApiHelper.clear() if(!@dbApiHelper.nil?)

      return warningsExist
    end
  end
end ; end end # module BRL ; module Genboree ; module Tools
