require 'brl/genboree/tools/workbenchRulesHelper'
require 'brl/genboree/tools/workbenchFormHelper'
require 'brl/genboree/rest/helpers/trackApiUriHelper'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require 'brl/genboree/rest/helpers/fileApiUriHelper'
require 'uri'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/rest/apiCaller'
include BRL::Genboree::REST

module BRL ; module Genboree ; module Tools
  class SampleFileLinkerRulesHelper < WorkbenchRulesHelper

    TOOL_ID = 'sampleFileLinker'

    def rulesSatisfied?(wbJobEntity, sectionsToSatisfy=[ :inputs, :outputs, :context, :settings ], toolIdStr=@toolIdStr)
      # Apply basic rules from the rules file (counts, basic types, other simple things)
      rulesSatisfied = super(wbJobEntity, sectionsToSatisfy, toolIdStr)

      if(rulesSatisfied)
        @dbu = BRL::Genboree::DBUtil.new("#{@genbConf.dbrcKey}", nil, nil)
        # Must pass the rest of the checks as well
        rulesSatisfied = false
        fileFormatSatisfied = true
        allFiles = true
        inputs = wbJobEntity.inputs
        inputs.each { |input|
          if(!@fileApiHelper.extractName(input))
            allFiles = false
          else # Make sure all files are sra/sff (if not compressed)
            uriObj = URI.parse(input)
            apiCaller = ApiCaller.new(uriObj.host, "#{uriObj.path}/type?", @hostAuthMap)
            apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
            apiCaller.get()
            type = JSON.parse(apiCaller.respBody)['data']['text']
            next if(type != 'text')
            apiCaller.setRsrcPath("#{uriObj.path}/format?")
            apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
            apiCaller.get()
            format = JSON.parse(apiCaller.respBody)['data']['text']
            if(format == 'sra' or format == 'sff')
              # We are fine
            else
              fileFormatSatisfied = false
            end
          end
        }
        # Check 1: either samples or sample set should be present
        if(allFiles)
          wbJobEntity.context['wbErrorMsg'] = "You must select at least one sample or sampleSet. "
        else
          # Check 2: All files MUST be SRA/SFF
          unless(fileFormatSatisfied)
            wbJobEntity.context['wbErrorMsg'] = "Only SRA or SFF files are allowed to be linked to samples."
          else
            rulesSatisfied = true
          end
        end

        # further checks defined in validateOrder function so that they may easily be reworked as warnings if needed
        validOrder, wbJobEntity = validateOrder(wbJobEntity)
        rulesSatisfied = false unless(validOrder)
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
      else # No warnings for now
        warningsExist = false
      end

      # Clean up helpers, which cache many things
      @trkApiHelper.clear() if(!@trkApiHelper.nil?)
      @dbApiHelper.clear() if(!@dbApiHelper.nil?)

      return warningsExist
    end

    # nicely display multiple error messages in a single bulleted list
    # @note this utility works around the default display of errors on the workbench
    # which places error message in a <ul><li> and closes those tags at the end of the
    # message
    def prepErrorMsg(wbErrorMsg)
    end

    # rule helper to give an error if the order of files is bad for the given inputs
    # @param [Hash] wbJobEntity the workbench job entity for this sampleFileLinker job
    # @return [Array<Boolean, Hash>] a boolean indicating success and a modified wbJobEntity
    #   hash with error messages if they exist
    # @note assumes input rules in toolConf for this tool require a file resource or
    #   a sample or sampleSet resource and that at least 1 file and 1 sample or sampleSet
    #   must be present
    def validateOrder(wbJobEntity)
      validOrder = true

      # classify inputs as a sample, sampleSet or a file
      file_indexes = []
      file_names = []
      sample_indexes = []
      filePattern = %r{^http://[^/]+/REST/v\d+/grp/[^/]+/db/[^/]+/file/([^/\?]+)}
      wbJobEntity.inputs.each_index{|ii|
        input = wbJobEntity.inputs[ii]
        if(input =~ filePattern)
          # then file
          file_indexes << ii
          file_names << $1
        else
          # then sample or sampleSet, based on toolConf assumption
          sample_indexes << ii
        end
      }

      # now check for a number of problems
      # prepare warning message to append to (if it already exists, add to it)
      wbJobEntity.context['wbErrorMsg'] = '' if(wbJobEntity.context['wbErrorMsg'].nil?)
      #wbJobEntity.context['wbErrorMsg'] << "\n</ul><ul>\n" # msg inserted into html already in ul, override it
      # (1) a file should be first
      if(file_indexes[0] != 0)
        # then a file is not first
        validOrder = false
        wbJobEntity.context['wbErrorMsg'] = "Your input starts with a sample, but it should start with a file. Please reorder your inputs so that a file comes first. Subsequent samples will be linked to this file.\n"
      end

      # (2) a file should not be last
      if(file_indexes[-1] == wbJobEntity.inputs.length - 1)
        # then a file is last
        validOrder = false
        wbJobEntity.context['wbErrorMsg'] = "Your input ends with a file with no subsequent samples. Please add the samples you were intending to link beneath this file or remove it from the inputs window.\n"
      end

      # (3) no two files should be neighbors
      prev_file_index = nil
      file_indexes.each_index{|file_counter|
        # file_counter e.g. 0, 1, 2, ... counts the number of inputs which are files
        # file_index 0, 3, 5, ... is the original index from the inputs for inputs which are file resources
        file_index = file_indexes[file_counter]
        if(prev_file_index.nil?)
          prev_file_index = file_index
          prev_file_counter = file_counter
        else
          if((file_index - prev_file_index).abs <= 1)
            # then 2 files are neighbors
            validOrder = false
            wbJobEntity.context['wbErrorMsg'] = "Your input has two files in immediate succession. Please reorder your inputs to include samples between these two files or remove one of the files from the inputs window.\n"
            break
          end
        end
        prev_file_index = file_index
        prev_file_counter = file_counter
      }
      
      return [validOrder, wbJobEntity]
    end
  end
end ; end; end # module BRL ; module Genboree ; module Tools
