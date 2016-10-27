require 'uri'
require 'brl/genboree/tools/workbenchRulesHelper'
require 'brl/genboree/tools/workbenchFormHelper'
require 'brl/genboree/rest/helpers/groupApiUriHelper'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require 'brl/genboree/rest/helpers/trackApiUriHelper'
require 'brl/genboree/rest/helpers/fileApiUriHelper'

module BRL ; module Genboree ; module Tools
  class SparkEpigenomeAtlasRulesHelper < WorkbenchRulesHelper
    RESULTS_FILES_BASE = "Spark"

    TOOL_ID = 'sparkEpigenomicAtlas'

    def rulesSatisfied?(wbJobEntity, sectionsToSatisfy=[ :inputs, :outputs, :context, :settings ], toolIdStr=@toolIdStr)
      rulesSatisfied = super(wbJobEntity, sectionsToSatisfy, toolIdStr)

      if(rulesSatisfied)
        filePath = wbJobEntity.context['file']
        userId = wbJobEntity.context['userId']
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
          else
            inputs = wbJobEntity.inputs
            outputs = wbJobEntity.outputs
            rulesSatisfied = true
          end
        end

        # ------------------------------------------------------------------
        # CHECK SETTINGS
        # ------------------------------------------------------------------
        if(sectionsToSatisfy.include?(:settings))
          # Check :settings together with info from :outputs :
          unless( sectionsToSatisfy.include?(:outputs) and sectionsToSatisfy.include?(:inputs))
            raise ArgumentError, "Cannot validate just :settings without info provided in :inputs and :outputs."
          else
            settings = wbJobEntity.settings
          end

          rulesSatisfied = false
          # CHECK 0: due to Windows path issues, we need to keep paths to files short (spark makes things
          # very long). We'll have to impose a length limit on analysisName
          analysisName = settings['analysisName']
          if(analysisName.size > 36)
            # FAILED: analysisName is too long, and can easily lead to problems on Windows
            wbJobEntity.context['wbErrorName'] = "Analysis Name Is Too Long For Spark"
            wbJobEntity.context['wbErrorMsg'] = "Analysis Name is used in building Spark folder and file names. Because of how Spark names its folders and files, Windows users can run into problems when trying to open results in the Spark GUI. This is because the file paths are longer than Windows supports.<br> <br>To decrease the likelihood of that happening to you or your collaborators, the Analysis Name is restricted to only 30 characters. With this&mdash;and the best practices mentioned in the Help&mdash;your Spark results should be viewable on a number of operating systems."
          else
            # CHECK 1: Does the analysis name already exist as a PatternBrowser/ sub-dir in output database?
            escAnalysisName = analysisName.split(/\//).map{|xx| CGI.escape(xx) }.join('/')
            filesRoot = @fileApiHelper.filesDirForDb(wbJobEntity.outputs.first)
            analysisSubDir = "#{filesRoot}/#{RESULTS_FILES_BASE}/#{escAnalysisName}"
            if(File.exists?(analysisSubDir))
              # FAILED: experiment name exists
              wbJobEntity.context['wbErrorName'] = "Analysis Name Already Exists"
              wbJobEntity.context['wbErrorMsg'] ="There is already a Spark analysis called '#{analysisName}' in the output database '#{@dbApiHelper.extractName(wbJobEntity.outputs.first)}'. Please pick a different name for your analysis."
            else
              # CHECK 2: Have we got either binSize or numBins?
              binSizeOrNum = settings['binSizeOrNum']
              if(binSizeOrNum == 'useBinSize')
                binSize = settings['binSize']
                if(binSize !~ /^\d+$/)
                  # FAILED: binSize not an integer
                  wbJobEntity.context['wbErrorName'] = "Invalid Bin Size"
                  wbJobEntity.context['wbErrorMsg'] = "The value for Bin Size ('#{binSize}') is not a positive integer."
                  continue = false
                else
                  binSize = binSize.to_i
                  continue = true
                end
              else # binSizeOrNum == 'useNumBins'
                numBins = settings['numBins']
                if(numBins !~ /^\d+$/)
                  # FAILED: binSize not an integer
                  wbJobEntity.context['wbErrorName'] = "Invalid # of Bins"
                  wbJobEntity.context['wbErrorMsg'] = "The value for # of Bins('#{numBins}') is not a positive integer."
                  continue = false
                else
                  numBins = numBins.to_i
                  continue = true
                end
              end # END CHECK 2: Have we got either binSize or numBins?
              if(continue)
                if(inputs.size > 1)
                  # CHECK: Each track/file has a color (must be blue or orange right now)
                  numDataSources = inputs.size - 1
                  # - we should have a <select> for each data source named "colLabel_0", "colLabel_1", etc
                  numDataSources.times { |ii|
                    selectId = "colLabel_#{ii}"
                    colLabel = settings[selectId].to_s.downcase
                    unless(colLabel == 'blue' or colLabel == 'orange')
                      trkOrFile = WorkbenchFormHelper.getNameFromURI(:trk, inputs[ii], true)
                      unless(trkOrFile)
                        trkOrFile = WorkbenchFormHelper.getNameFromURI(:file, inputs[ii], true, true)
                      end
                      # FAILED: binSize not an integer
                      wbJobEntity.context['wbErrorName'] = "Invalid Color"
                      wbJobEntity.context['wbErrorMsg'] = "The color for track or file '#{trkOrFile}' must be 'blue' or 'orange'. Currently Spark only supports those 2 options, and not '#{colLabel}'."
                    else
                      rulesSatisfied = true
                    end
                  }
                else
                  rulesSatisfied = true
                end
              end
            end
          end
        end
      end

      # Clean up helpers, which cache many things
      @fileApiHelper.clear() if(!@fileApiHelper.nil?)
      @trkApiHelper.clear() if(!@trkApiHelper.nil?)
      @dbApiHelper.clear() if(!@dbApiHelper.nil?)
      @grpApiHelper.clear() if(!@grpApiHelper.nil?)

      return rulesSatisfied
    end
  end
end; end; end
