require 'brl/genboree/tools/workbenchRulesHelper'
require 'brl/genboree/tools/workbenchFormHelper'
require 'brl/genboree/rest/helpers/trackApiUriHelper'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require 'brl/genboree/rest/helpers/fileApiUriHelper'
require 'uri'

module BRL ; module Genboree ; module Tools
  class SmallRNAPashMapperRulesHelper < WorkbenchRulesHelper

    TOOL_ID = 'smallRNAPashMapper'

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
        # Check 1: are all the input files from the same db version?
        dbVer1 = @dbApiHelper.dbVersion(inputs[0], @hostAuthMap)
        puts "dbVer #{dbVer1}"
        match = true
        inputs.each  {|file|
          if(@dbApiHelper.dbVersion(file, @hostAuthMap) != dbVer1)
            match = false
            break
          end
        }
        if(!match) # Failed: All files do not come from the same db versions
          wbJobEntity.context['wbErrorMsg'] = "Invalid Inputs: All the input files(s) do not belong to the same database version. All input files(s) must come either only from 'hg18', 'hg19', 'mm9', 'dm5.1' 'calJac3' or 'taeGut1'. "
        else
          # Check 3: the input db version must match the output db version
          if(dbVer1 != @dbApiHelper.dbVersion(outputs[0], @hostAuthMap)) # Failed: input and output db versions don't match
            wbJobEntity.context['wbErrorMsg'] = "Invalid Inputs: The database version of the input files(s) must match the version of the output database. Both should either be only 'hg18', 'hg19', 'mm9', 'dm5.1', 'calJac3' or 'taeGut1'."
          else
            # Check 4: check if the db version is either hg18 or mm9 or
            if(dbVer1.downcase != 'hg18' and dbVer1.downcase != 'mm9' and dbVer1.downcase != 'caljac3' and dbVer1.downcase != 'taegut1' and dbVer1.downcase != 'hg19' and dbVer1.downcase != 'dm5.1') # Failed
              wbJobEntity.context['wbErrorMsg'] = "Invalid Inputs: The database version of the input file(s) and/or output database have to be either 'hg18', 'hg19', 'mm9', 'calJac3' ,'dm5.1' or 'taeGut1'."
            else
              # Check 5: Make sure all of the track inputs (if any, are non high density)
              isHdhv = false
              inputs.each { |input|
                if(BRL::Genboree::REST::Helpers::TrackApiUriHelper::EXTRACT_SELF_URI =~ input)
                  isHdhv = @trkApiHelper.isHdhv?(input, @hostAuthMap)
                end
                break if(isHdhv)
              }
              if(isHdhv) # Failed
                wbJobEntity.context['wbErrorMsg'] = "Invalid Inputs: One or more of the ROI Tracks is a High Density High Volume (HDHV) track."
              else
                # Check 6: The first input has to be a file
                if(BRL::Genboree::REST::Helpers::FileApiUriHelper::EXTRACT_SELF_URI !~ inputs[0])
                  wbJobEntity.context['wbErrorMsg'] = "Invalid Inputs: The first input MUST be a file. "
                else
                  rulesSatisfied = true
                end
              end
            end
          end
        end
        if(sectionsToSatisfy.include?(:settings))
          # Check :settings together with info from :outputs :
          unless( sectionsToSatisfy.include?(:outputs) and  sectionsToSatisfy.include?(:inputs) )
            raise ArgumentError, "Cannot validate just :settings for this tool without info provided in both :inputs and :outputs."
          end

          rulesSatisfied = false
          # Check 1: length of type and subtype should be less than 100 chars
          type = wbJobEntity.settings['lffType']
          subtype = wbJobEntity.settings['lffSubType']
          if(type.length >= 100 or subtype.length >= 100)
            wbJobEntity.context['wbErrorMsg'] = "Invalid Inputs: The length of the type and subtype of the track name should be smaller than 100 characters. "
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
        # Generate a warning if the provided track name already exists.
        outputDb = @dbApiHelper.extractPureUri(wbJobEntity.outputs[0])
        trackName = CGI.escape("#{wbJobEntity.settings['lffType']}:#{wbJobEntity.settings['lffSubType']}")
        trkUri = "#{outputDb.chomp("?")}/trk/#{trackName}?"
        if(@trkApiHelper.exists?(trkUri))
          wbJobEntity.context['wbErrorMsg'] = "The track: #{CGI.unescape(trackName)} already exists in the target database. Are you sure you want to add data to this track? "
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
