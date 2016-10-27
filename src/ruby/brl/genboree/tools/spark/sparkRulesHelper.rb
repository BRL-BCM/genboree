require 'uri'
require 'brl/genboree/tools/workbenchRulesHelper'
require 'brl/genboree/tools/workbenchFormHelper'
require 'brl/genboree/rest/helpers/groupApiUriHelper'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require 'brl/genboree/rest/helpers/trackApiUriHelper'
require 'brl/genboree/rest/helpers/fileApiUriHelper'

module BRL ; module Genboree ; module Tools
  class SparkRulesHelper < WorkbenchRulesHelper
    RESULTS_FILES_BASE = "Spark%20-%20Results"
    SPARK_COLORS = { :blue => true, :green => true, :orange => true, :pink => true, :purple => true }

    TOOL_ID = 'spark'


    def customToolChecks(wbJobEntity, sectionsToSatisfy=[ :inputs, :outputs, :context, :settings ], toolIdStr=@toolIdStr)
      rulesSatisfied = true

      # ------------------------------------------------------------------
      # CHECK SETTINGS
      # ------------------------------------------------------------------
      if(sectionsToSatisfy.include?(:settings))
        settings = wbJobEntity.settings
        inputs = wbJobEntity.inputs
        # Must pass the rest of the checks as well
        rulesSatisfied = false

        # CHECK 0: due to Windows path issues, we need to keep paths to files short (spark makes things
        # very long). We'll have to impose a length limit on analysisName
        analysisName = settings['analysisName']
        if(analysisName.size > 48)
          # FAILED: analysisName is too long, and can easily lead to problems on Windows
          wbJobEntity.context['wbErrorName'] = "Analysis Name Is Too Long For Spark"
          wbJobEntity.context['wbErrorMsg'] = "Analysis Name is used in building Spark folder and file names. Because of how Spark names its folders and files, Windows users can run into problems when trying to open results in the Spark GUI. This is because the file paths are longer than Windows supports.<br> <br>To decrease the likelihood of that happening to you or your collaborators, the Analysis Name is restricted to only 30 characters. With this&mdash;and the best practices mentioned in the Help&mdash;your Spark results should be viewable on a number of operating systems."
        else
          # CHECK 1: Does the analysis name already exist as a Spark/ sub-dir in output database?
          escAnalysisName = analysisName.split(/\//).map{|xx| CGI.escape(xx) }.join('/')
          filesRoot = @fileApiHelper.filesDirForDb(wbJobEntity.outputs.first)
          analysisSubDir = "#{filesRoot}/#{RESULTS_FILES_BASE}/#{escAnalysisName}"
          if(File.exists?(analysisSubDir))
            # FAILED: experiment name exists
            wbJobEntity.context['wbErrorMsg'] = "ALREADY EXISTS: There is already a Spark analysis called '#{analysisName}' in the output database '#{@dbApiHelper.extractName(wbJobEntity.outputs.first)}'. Please pick a different name for your analysis."
          else
            numBins = settings['numBins'].strip
            if(numBins !~ /^\d+$/)
              # FAILED: binSize not an integer
              wbJobEntity.context['wbErrorMsg'] = "INVALID SETTING: The value for # of Bins('#{numBins}') is not a positive integer."
            else
              # PASS: binSize is an integer
              numBins = numBins.to_i
              # CHECK: do we have an roiTrack setting?
              roiTrack = settings['roiTrack']
              unless(roiTrack and !roiTrack.empty?)
                # FAILED: color not valid
                wbJobEntity.context['wbErrorMsg'] = "NO ROI TRACKS: It doesn't look like you indicated which of your tracks contains the ROI."
              else
                # Get the complete list of tracks
                allTrkEntities = WorkbenchFormHelper.buildEntitiesListMap(inputs, 'trk', @userId, @rackEnv)
                trkList = allTrkEntities.values.flatten
                # CHECK: do we have too many data tracks?
                if(trkList.size > 20)
                  # FAILED: too many data tracks / can't visualize in Spark easily
                  wbJobEntity.context['wbErrorMsg'] = "TOO MANY DATA TRACKS: To ensure you can sensibly visualize your Spark results, you cannot have more than 20 data tracks. This also keeps result load times reasonable in the Spark UI."
                else
                  # CHECK: Each track/file has a color (must be blue or orange right now), except ROI track which should have nil color
                  # - the ROI track is the only one which can have a nil color represented
                  # - if colLabels array is passed directly, the ROI won't have an entry, so prime numNilColors to 1 (for the ROI)
                  # - if doing colLabel_X fields from the tool UI form, we'll find the ROI "nil" color entry naturally so prime to 0
                  numNilColors = ((settings['colLabels'] and !settings['colLabels'].empty?) ? 1 : 0)
                  # - we should have a <select> for each data source named "colLabel_0", "colLabel_1", etc
                  # - because the ROI track is being removed from the list before it arrives here, we
                  #   actually have trkList.size + 1 colLabel_ settings. To avoid a bug where the ROI track is
                  #   the LAST one, we must make sure to check all (trkList.size + 1) colLabels!
                  #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "roiTrack:\n    #{roiTrack.inspect}\ntrkList:\n    #{trkList.inspect}\settings:\n    #{settings.inspect}")
                  (trkList.size + 1).times { |ii|
                    trk = trkList[ii]
                    #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "\n#{ii.inspect} => trk: #{trk.inspect}\ncolLabel_#{ii} => #{settings["colLabel_#{ii}"].inspect}\nROI? #{(trk == roiTrack).inspect}\n#{'-'*40}\n")
                    if(trk and (trk != roiTrack)) # skip ROI track item (shouldn't have a colLabel_X and should be null if in colLabels array if called that way)
                      # If have colLabels directly, use that
                      if(settings['colLabels'] and !settings['colLabels'].empty?)
                        colLabel = settings['colLabels'][ii].to_s.downcase
                      else # Use the values of colLabel_0, colLabel_1, etc
                        selectId = "colLabel_#{ii}"
                        colLabel = settings[selectId].to_s.downcase
                      end
                      # Now validate color value
                      if(colLabel.nil? or colLabel.empty?)
                        numNilColors += 1
                      else
                        colLabelSym = colLabel.to_sym
                        unless(SPARK_COLORS.key?(colLabelSym))
                          trkOrFile = WorkbenchFormHelper.getNameFromURI(:trk, inputs[ii], true)
                          unless(trkOrFile)
                            trkOrFile = WorkbenchFormHelper.getNameFromURI(:file, inputs[ii], true, true)
                          end
                          # FAILED: color not valid
                          wbJobEntity.context['wbErrorMsg'] = "INVALID SETTING: The color for track or file '#{trkOrFile}' must be one of: 'blue', 'green', 'orange', 'pink', or 'purple'. Currently Spark does not support the color '#{colLabel}'."
                        else
                          rulesSatisfied = true
                        end
                      end
                    end
                  }
                  # Should no data tracks with nil color. Only the ROI has nil color.
                  if(numNilColors > 1)
                    wbJobEntity.context['wbErrorMsg'] = "INVALID SETTING: #{numNilColors.inspect} of the data (non-ROI) tracks has NO color set. All data tracks must have a color."
                    rulesSatisfied = false
                  else
                    # ROI must be a non HD track
                    roiTrkSelect = settings['roiTrkSelect']
                    if(@trkApiHelper.isHdhv?(roiTrkSelect, @hostAuthMap))
                      wbJobEntity.context['wbErrorMsg'] = "INVALID INPUT: The Regions-of-Interest track cannot be a high density track. Please select another ROI track."
                      rulesSatisfied = false
                    end
                  end
                end
              end
            end
          end
        end
      end
      return rulesSatisfied
    end
  end
end; end; end
