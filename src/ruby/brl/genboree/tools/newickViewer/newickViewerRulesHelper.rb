require 'uri'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/tools/workbenchRulesHelper'
require 'brl/genboree/tools/workbenchFormHelper'
require 'brl/genboree/helpers/sniffer'
require 'brl/genboree/rest/wrapperApiCaller'
require 'tempfile'
include BRL::Genboree::REST

module BRL ; module Genboree ; module Tools
  class NewickViewerRulesHelper < WorkbenchRulesHelper

    TOOL_ID = 'newickViewer'

    @@iter = 0
    def rulesSatisfied?(wbJobEntity, sectionsToSatisfy=[ :inputs, :outputs, :context, :settings ], toolIdStr=@toolIdStr)
      # Apply basic rules from the rules file (counts, basic types, other simple things)
      rulesSatisfied = super(wbJobEntity, sectionsToSatisfy, toolIdStr)
      @@iter += 1
      if(rulesSatisfied)
        begin
          inputs = wbJobEntity.inputs
          userId = wbJobEntity.context['userId']
          # Make sure the input file is a newick file
          fileUriObj = URI.parse(inputs[0])
          sniffer = BRL::Genboree::Helpers::Sniffer.new()
          # Get number of records needed by Sniffer
          numRecs = sniffer.getFormatConf('newick').nRecs
          apiCaller = ApiCaller.new(fileUriObj.host, "#{fileUriObj.path}/data?", @hostAuthMap)
          apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
          tmpFileName = "#{Time.now.to_f}.#{rand(10_000)}.#{CGI.escape(File.basename(@fileApiHelper.extractName(fileName)))}"
          # Make Tempfile. Auto-cleaned up when we call close. Use untainted Dir::tmpdir as a best practice.
          tempNewickFileObj  = Tempfile.new(tmpFileName, Dir::tmpdir.untaint)
          numLines = 0
          apiCaller.get() { |chunk|
            tempNewickFileObj.print(chunk)
            numLines += chunk.count("\n")
            break if(numLines >= numRecs)
          }
          # When all done writing to Tempfile, use flush() to ensure it's written to disk.
          # - otherwise, when things like Sniffer (or whatever) read from the file it may be empty (!!) or much smaller than it should be!
          # - this is important here because we can't close() the tempfile until ALL done with it (close == delete/clean the tempfile!)
          tempNewickFileObj.flush()
          # tempNewickFileObj.path gives the entire path and file name
          sniffer.filePath = tempNewickFileObj.path
          unless(sniffer.detect?('newick'))
            rulesSatisfied = false
            wbJobEntity.context['wbErrorMsg'] = "INVALID_FILE_FORMAT: Your input file is not a newick file."
          end # if(sniffer.detect?('newick'))
          # Tempfile should be closed only after Sniffer method is called
          tempNewickFileObj.close()
          # ------------------------------------------------------------------
          # CHECK SETTINGS
          # ------------------------------------------------------------------
          if(sectionsToSatisfy.include?(:settings))
          end
        ensure
          `rm -f #{fileName}`
        end
      end

      # Clean up helpers, which cache many things
      @dbApiHelper.clear() if(!@dbApiHelper.nil?)
      return rulesSatisfied
    end

    # It's a good idea to catch any potential errors now instead of relying on the job to do validation because,
    # the job may get queued and the user wouldn't be notified  for an unnecessarily long time that they have something minor wrong with their inputs.
    #
    # [+returns+] boolean
    def warningsExist?(wbJobEntity)
      warningsExist = true
      inputs = wbJobEntity.inputs
      if(wbJobEntity.context['warningsConfirmed'])
        # The user has confirmed the warnings and wants to proceed
        warningsExist = false
      else
        warningsExist = false # No warnings for now
      end
      return warningsExist
    end
  end
end ; end; end # module BRL ; module Genboree ; module Tools
