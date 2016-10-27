require 'brl/genboree/tools/workbenchRulesHelper'
require 'brl/genboree/tools/workbenchFormHelper'
require 'brl/genboree/rest/helpers/trackApiUriHelper'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require 'brl/genboree/rest/helpers/fileApiUriHelper'
require 'brl/genboree/rest/apiCaller'
require 'brl/genboree/dbUtil'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/abstract/resources/user'
module BRL ; module Genboree ; module Tools
  class EpigenomeAtlasSimilaritySearchRulesHelper < WorkbenchRulesHelper
    RESULTS_FILES_BASE = "epigenomeAtlasSimilaritySearch"

    TOOL_ID = 'epigenomeAtlasSimilaritySearch'

    def rulesSatisfied?(wbJobEntity, sectionsToSatisfy=[ :inputs, :outputs, :context, :settings ], toolIdStr=@toolIdStr)
      # Apply basic rules from the rules file (counts, basic types, other simple things)
      rulesSatisfied = super(wbJobEntity, sectionsToSatisfy, toolIdStr)

      if(rulesSatisfied)
        @dbu = BRL::Genboree::DBUtil.new("#{@genbConf.dbrcKey}", nil, nil)
        userId = wbJobEntity.context['userId']
        dbVer = nil
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
          # CHECK 1: Are there any duplicate tracks in inputs?
          if(@trkApiHelper.hasDups?(wbJobEntity.inputs))
            # FAILED: has some dups.
            wbJobEntity.context['wbErrorMsg'] = "Some tracks are in the inputs multiple times."
          else # OK: no track dups
            # CHECK 2: track & databases are ALL version-compatible (empty version matches any non-empty in this call)
            unless(checkDbVersions(inputs + outputs, skipNonDbUris=true))
              # FAILED: No, some versions didn't match
              wbJobEntity.context['wbErrorName'] = 'Genome Incompatibility'
              wbJobEntity.context['wbErrorMsg'] =
              {
                :msg => 'Some tracks are from a different genome assembly version than other tracks, or from the output database.',
                :type => :versions,
                :info =>
                {
                  :inputs =>  @trkApiHelper.dbVersionsHash(inputs),
                  :outputs => @dbApiHelper.dbVersionsHash(outputs)
                }
              }
            else # OK: versions
              # CHECK 3: Input data must be on Hg18 or Hg19 to search Epigenome Atlas
              dbVer = @dbApiHelper.dbVersion(inputs.first)
              if(dbVer.nil? or dbVer.empty? or (dbVer != 'hg18' and dbVer != 'hg19'))
                # FAILED: input track not from Hg18 or Hg19 database
                wbJobEntity.context['wbErrorName'] = 'Genome Incompatibility'
                wbJobEntity.context['wbErrorMsg'] =
                {
                  :msg => "Your input query track must be from Hg18 or Hg19 in order to query an Epigenomic Atlas data freeze.",
                  :type => :versions,
                  :info =>
                  {
                    :inputs =>  @trkApiHelper.dbVersionsHash(inputs),
                    :outputs => @dbApiHelper.dbVersionsHash(outputs)
                  }
                }
              else # OK: user has query from hg18 or hg19
                if(inputs.size == 1)
                  wbJobEntity.settings['queryTrack'] = inputs[0]
                end
                rulesSatisfied = true 
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

          # CHECK 1: Does the analysis name already exist as a epigenomeAtlasSimilaritySearch/ sub-dir in output database?
          analysisName = wbJobEntity.settings['analysisName']
          outputDbUri = wbJobEntity.outputs.first
          escAnalysisName = analysisName.split(/\//).map{|xx| CGI.escape(xx) }.join('/')
          filesRoot = @fileApiHelper.filesDirForDb(wbJobEntity.outputs.first)
          analysisSubDir = "#{filesRoot}/#{RESULTS_FILES_BASE}/#{escAnalysisName}"
          if(File.exists?(analysisSubDir))
            # FAILED: experiment name exists
            wbJobEntity.context['wbErrorName'] = "Analysis Name Already Exists"
            wbJobEntity.context['wbErrorMsg'] =
            {
              :msg => "There is already an Epigenome Atlast Similarity Search analysis called '#{analysisName}' in the output database '#{@dbApiHelper.extractName(wbJobEntity.outputs.first)}'. Please pick a different name for your analysis.",
              :type => :analysisNameExists
            }
          else # OK: analysis name unique in database

            # CHECK 2: Does input track genome version match an atlas version?
            # - get the assembly version of their input score tracks (already checked that all inputs and outputs are the same version)
            # - check it it matches a supported one
            inputDbVersion = dbVer
            unless(inputDbVersion == 'hg18' or inputDbVersion == 'hg19')
              # FAILED: experiment name exists
              wbJobEntity.context['wbErrorName'] = 'Genome Incompatibility'
              wbJobEntity.context['wbErrorMsg'] =
              {
                :msg => "This tool compares against Epigenome Atlas data on genome assembly versions 'hg18' and 'hg19'. Your input track is not from a compatible database based on one of these assembly versions.",
                :type => :versions,
                :info =>
                {
                  :inputs =>  @trkApiHelper.dbVersionsHash(inputs),
                  :outputs => @dbApiHelper.dbVersionsHash(outputs)
                }
              }
            else # OK: input data matches Atlas assembly version
             
              inputs = wbJobEntity.inputs
              # Check 4: If 1 input, we need to have either a selected window size or one of the pre-selected ROI tracks
              regionsPresent = true
              roiTrack = wbJobEntity.settings['roiTrack']
              if(inputs.size == 1)
                customRes = wbJobEntity.settings['customResolution']
                fixedRes = wbJobEntity.settings['fixedResolution']
                if(customRes !~ /^\d+$/ and fixedRes != "high" and fixedRes != "medium" and fixedRes != "low" and (roiTrack.nil? or roiTrack.empty?))
                  regionsPresent = false
                end
              end
              if(!regionsPresent)
                wbJobEntity.context['wbErrorMsg'] = "Invalid Input: No Window or Regions of Interest selected. Please select either a window size or one of Regions of Interest (ROI) tracks to run the tool. "
              else
                # Check 5: custom resolution cannot be larger than 20_000_000 or smaller than 0
                correctRes = true
                correctRes = false if(!customRes.nil? and !customRes.empty? and (customRes !~ /^\d+$/ or ( customRes =~ /^\d+$/ and (customRes.to_i > 20_000_000 or customRes.to_i <= 0))))
                if(!correctRes)
                  wbJobEntity.context['wbErrorMsg'] = "Invalid Input: Custom Resolution is either invalid or too large. Please select an integer resolution smaller or equal to 20_000_000 and larger than 0. "
                else
                  # Check 6: make sure folder with analysisName does not already exist
                  analysisName = CGI.escape(wbJobEntity.settings['analysisName'])
                  dbUri = @dbApiHelper.extractPureUri(outputDbUri)
                  uri = URI.parse(dbUri)
                  host = uri.host
                  rcscUri = uri.path.chomp("?")
                  genbConf = BRL::Genboree::GenboreeConfig.load()
                  apiDbrc = @superuserApiDbrc
                  rcscUri << "/file/Signal%20Search/#{analysisName}/summary.txt?"
                  apiCaller = ApiCaller.new(host, rcscUri, @hostAuthMap)
                  retVal = ""
                  # Making internal API call
                  apiCaller.initInternalRequest(@rackEnv, genbConf.machineNameAlias) if(@rackEnv)
                  resp = apiCaller.get()
                  if(apiCaller.succeeded?) # Failed. Should not have existed
                    wbJobEntity.context['wbErrorMsg'] = "Invalid Input: A folder for the analysis name: #{analysisName.inspect} already exists for this database. Please select some other analysis name."
                  else
                    # Check 7: if ROI present the cutt off value should not exceed that in the genb conf
                    cutoff = true
                    trkUri = nil
                    noOfTargets = wbJobEntity.settings['epiAtlasScrTracks'].size
                    if(noOfTargets > 100)
                      wbJobEntity.context['wbErrorMsg'] = "Invalid Input: The maximun number of target tracks cannot exceed 100 tracks."
                    else
                      roiTrkOK = true
                      if(inputs.size == 2)
                        if(@trkApiHelper.isHdhv?(roiTrack, @hostAuthMap))
                          wbJobEntity.context['wbErrorMsg'] = "INVALID_INPUT: The Regions-of-Interest track cannot be a high density track. Please select another track." 
                          roiTrkOK = false
                        end
                      end
                      rulesSatisfied = true if(roiTrkOK)
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
        inputs = wbJobEntity.inputs
        outputDbUri = wbJobEntity.outputs.first
        outputDbName = @dbApiHelper.extractName(outputDbUri)
        # CHECK 1: Do any of the inputs have empty/blank db versions?
        if(@dbApiHelper.anyDbVersionsEmpty?(inputs))
          # WARNING: Yes some/all versions are empty/blank
          wbJobEntity.context['wbErrorName'] = "Can't Verify Genome Compatibility"
          wbJobEntity.context['wbErrorMsg'] =
          {
            :msg => "The genome assembly version is empty/blank for the database of some input tracks. The genomes' coordinate systems may or may not be compatible.",
            :type => :versions,
            :info =>
            {
              :inputs =>  @trkApiHelper.dbVersionsHash(inputs),
              :outputs => @dbApiHelper.dbVersionsHash(outputs)
            }
          }
        else # OK: no empty genome version strings
          # ALL OK
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
