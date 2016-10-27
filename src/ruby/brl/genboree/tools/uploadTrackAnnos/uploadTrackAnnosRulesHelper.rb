require 'brl/genboree/tools/workbenchRulesHelper'
require 'brl/genboree/tools/workbenchFormHelper'
require 'brl/genboree/rest/helpers/trackApiUriHelper'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require 'uri'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/rest/apiCaller'
include BRL::Genboree::REST

module BRL ; module Genboree ; module Tools
  class UploadTrackAnnosRulesHelper < WorkbenchRulesHelper

    TOOL_ID = 'uploadTrackAnnos'

    def rulesSatisfied?(wbJobEntity, sectionsToSatisfy=[ :inputs, :outputs, :context, :settings ], toolIdStr=@toolIdStr)
      # Apply basic rules from the rules file (counts, basic types, other simple things)
      rulesSatisfied = super(wbJobEntity, sectionsToSatisfy, toolIdStr)

      if(rulesSatisfied)
        @dbu = BRL::Genboree::DBUtil.new("#{@genbConf.dbrcKey}", nil, nil)
        # Must pass the rest of the checks as well
        rulesSatisfied = false
        outputs = wbJobEntity.outputs
        inputs = wbJobEntity.inputs
        # ------------------------------------------------------------------
        # Check Inputs/Outputs
        # ------------------------------------------------------------------
        # Check 1: does user have write permission to the db?
        userId = wbJobEntity.context['userId']
        # Check 2: are all the input files from the same db version?
        if(inputs.size != 0)
          unless(checkDbVersions(inputs + outputs, skipNonDbUris=true)) # Failed
            wbJobEntity.context['wbErrorMsg'] = "Database version of one or more input file(s) do not match target database."
          else
            rulesSatisfied = true
          end
        else
          rulesSatisfied = true
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
          format = wbJobEntity.settings['inputFormat']

          # Check #1: Unless the format is lff, the type, subtype and class name must be set properly
          unless(format == 'lff')
            lffType = wbJobEntity.settings['lffType']
            lffSubType = wbJobEntity.settings['lffSubType']
            lffClass = wbJobEntity.settings['trackClassName']
            classOK = true
            if(format != 'wig' and format != 'bedGraph' and format !~ /^bigwig$/i)
              if( lffClass.nil? or lffClass.empty? or lffClass =~ /\t/ or lffClass =~ /^\s/ or lffClass =~ /\s$/ )
                wbJobEntity.context['wbErrorMsg'] = "INVALID_INPUT: The 'Track Class' field is either empty or has a tab character or begins/ends with an empty character. "
                classOK = false
              end
            end
            if(classOK)
              if(format != 'vcf' and format != 'gff3' and ( lffSubType.nil? or lffSubType.empty? or lffSubType =~ /:/ or lffSubType =~ /\t/ or lffSubType =~ /^\s/ or lffSubType =~ /\s$/ ) )
                wbJobEntity.context['wbErrorMsg'] = "INVALID_INPUT: The 'Track Subtype' field is either empty or has an illegal character(':' or a tab or beginning/ending with an empty character). "
              else
                if(format != 'vcf' and format != 'gff3' and ( lffType.nil? or lffType.empty? or lffType =~ /:/ or lffType =~ /\t/ or lffType =~ /^\s/ or lffType =~ /\s$/ ) )
                  wbJobEntity.context['wbErrorMsg'] = "INVALID_INPUT: The 'Track Type' field is either empty or has an illegal character(':' or a tab or beginning/ending with an empty character). "
                else
                  # For vcf, 'subtype' cannot be empty
                  subtype = wbJobEntity.settings['subtype']
                  subtypeOK = true
                  if(format == 'vcf' and ( subtype.nil? or subtype.empty? or subtype =~ /:/ or subtype =~ /\t/ or subtype =~ /^\s/ or subtype =~ /\s$/ ))
                    subtypeOK = false
                  end
                  unless(subtypeOK)
                    wbJobEntity['wbErrorMsg'] = "INVALID_INPUT: The 'Track Subtype' field is either empty or has an illegal character(':' or a tab or beginning/ending with an empty character)."
                  else
                    rulesSatisfied = true
                  end
                end
              end
            end
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
      else # Look for warnings
        # no warnings for now
        # CHECK 1: does the output db already have any of the input tracks (Only do this if the input format is not lff since there is no way of knowing the track name)
        # Make an API call (internal?) to get the list of tracks from the target database
        warnings = false
        format = wbJobEntity.settings['inputFormat']
        if(format != 'lff' and format != 'vcf' and format != 'gff3')
          trk = "#{wbJobEntity.settings['lffType']}:#{wbJobEntity.settings['lffSubType']}"
          outputs = wbJobEntity.outputs
          outputUri = URI.parse(wbJobEntity.outputs[0])
          apiCaller = ApiCaller.new(outputUri.host, "#{outputUri.path}/trks?detailed=false&connect=false", @hostAuthMap)
          apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
          apiCaller.get()
          resp = JSON.parse(apiCaller.respBody)
          trkList = resp['data']
          trkPresentList = []
          trkList.each { |trkInDb|
            if(trk == trkInDb['text'])
              warnings = true
              break
            end
          }
          if(warnings)
            errorMsg = "The track: #{trk.inspect} is already present in the target database. Launching the job will add data to this track."
            wbJobEntity.context['wbErrorMsg'] = errorMsg
            wbJobEntity.context['wbErrorMsgHasHtml'] = true
          else
            # If the user is uploading bed/bedgraph, present a warning since a 4column bed file looks exactly like a bedgraph file
            if(format == 'bed' or format == 'bedGraph')
              wbJobEntity.context['wbErrorMsg'] = "You have selected #{format} as your input data file format. Are you sure you will be uploading a #{format} file? Please note, a 4-column bed file may look exactly like a bedGraph file if the values in the 4th column are numeric. <br>&nbsp;<br>More information on the distinction between BED and BedGraph file formats can be found at <a href=\"http://genome.ucsc.edu/FAQ/FAQformat.html\" target=\"blank\">http://genome.ucsc.edu/FAQ/FAQformat.html</a>"
              wbJobEntity.context['wbErrorMsgHasHtml'] = true
            else
              warningsExist = false
            end
          end
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
end ; end; end # module BRL ; module Genboree ; module Tools
