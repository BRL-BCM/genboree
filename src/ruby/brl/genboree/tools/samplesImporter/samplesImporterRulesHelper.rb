require 'brl/genboree/tools/workbenchRulesHelper'
require 'brl/genboree/tools/workbenchFormHelper'
require 'brl/genboree/rest/helpers/trackApiUriHelper'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require 'brl/genboree/rest/helpers/fileApiUriHelper'
require 'brl/genboree/rest/helpers/sampleSetApiUriHelper'
require 'uri'
require 'brl/genboree/abstract/resources/user'
require 'brl/genboree/dbUtil'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/rest/apiCaller'
require 'brl/util/util'
include BRL::Genboree::REST

module BRL ; module Genboree ; module Tools
  class SamplesImporterRulesHelper < WorkbenchRulesHelper

    TOOL_ID = 'samplesImporter'
    MAX_FILE_SIZE = 25 * 1024 * 1024

    def rulesSatisfied?(wbJobEntity, sectionsToSatisfy=[ :inputs, :outputs, :context, :settings ], toolIdStr=@toolIdStr)
      # Apply basic rules from the rules file (counts, basic types, other simple things)
      rulesSatisfied = super(wbJobEntity, sectionsToSatisfy, toolIdStr)

      if(rulesSatisfied)
        @dbu = BRL::Genboree::DBUtil.new("#{@genbConf.dbrcKey}", nil, nil)
        # Must pass the rest of the checks as well
        rulesSatisfied = false
        outputs = wbJobEntity.outputs
        # ------------------------------------------------------------------
        # Check Inputs/Outputs
        # ------------------------------------------------------------------
        # Check 1: does user have write permission to the db?
        userId = wbJobEntity.context['userId']
        unless(@dbApiHelper.accessibleByUser?(outputs.first, userId, CAN_WRITE_CODES))
          # FAILED: doesn't have write access to output database
          wbJobEntity.context['wbErrorMsg'] =
          {
            :msg => "Access Denied: You don't have permission to write to the output database.",
            :type => :writeableDbs,
            :info => @dbApiHelper.accessibleDatabasesHash(outputs, userId, CAN_WRITE_CODES)
          }
        else # OK: user can write to output database
          # Check 2: Make sure user doesn't have both sampleSets and Db in outputs. Also check if all sampleSets belong to the same db
          dbPresent = false
          sampleSetPresent = false
          previousDb = nil
          differentDb = false
          outputs.each { |output|
            if(output =~ BRL::Genboree::REST::Helpers::SampleSetApiUriHelper::NAME_EXTRACTOR_REGEXP) # sampleSet
              sampleSetPresent = true
              if(!previousDb.nil?)
                if(previousDb != @dbApiHelper.extractPureUri(output))
                  differentDb = true
                  break
                end
              end
              previousDb = @dbApiHelper.extractPureUri(output)
            else # db
              dbPresent = true
            end
          }
          if(dbPresent and sampleSetPresent)
            wbJobEntity.context['wbErrorMsg'] = "You cannot drag over both sampleSets and Database as Output Targets. "
          elsif(differentDb)
            wbJobEntity.context['wbErrorMsg'] = "All sampleSets MUST belong to the same database."
          else
            rulesSatisfied = true
          end
          # ------------------------------------------------------------------
          # CHECK SETTINGS
          # ------------------------------------------------------------------
          if(sectionsToSatisfy.include?(:settings))
            # Change the job into a cluster job if there are more than 1 inputs or the input is a folder/file entity lists or the size of the uncompressed file is larger than 25 Megs
            inputs = wbJobEntity.inputs
            if(inputs.size > 1) # More than 1 inputs, change it to a cluster job
              wbJobEntity.context['queue'] = @genbConf.gbDefaultPrequeueQueue
            elsif(inputs.size == 1 and !@fileApiHelper.extractName(inputs[0])) # One non file input
              wbJobEntity.context['queue'] = @genbConf.gbDefaultPrequeueQueue
            elsif(inputs.size == 1 and @fileApiHelper.extractName(inputs[0])) # Input is a file, check the type and size, and sample names
              uriObj = URI.parse(inputs[0])
              # check type
              apiCaller = ApiCaller.new(uriObj.host, "#{uriObj.path}/type?", @hostAuthMap)
              apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
              apiCaller.get()
              fileType = JSON.parse(apiCaller.respBody)['data']['text']
              if(fileType != 'text')
                wbJobEntity.context['queue'] = @genbConf.gbDefaultPrequeueQueue
              else
                # check size
                apiCaller = ApiCaller.new(uriObj.host, "#{uriObj.path}/size?", @hostAuthMap)
                apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
                apiCaller.get()
                fileSize = JSON.parse(apiCaller.respBody)['data']['number']
                if(fileSize >= MAX_FILE_SIZE)
                  wbJobEntity.context['queue'] = @genbConf.gbDefaultPrequeueQueue
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
      else # No warnings for now
        warningMsg = ''
        # two types of warnings to check
        sampleSetNameWarning = true
        sampleNameWarning = true
        # first check format of input file
        inputs = wbJobEntity.inputs
        uriObj = URI.parse(inputs[0])
        apiCaller = ApiCaller.new(uriObj.host, "#{uriObj.path}/format?", @hostAuthMap)
        apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
        apiCaller.get()
        if(apiCaller.succeeded?)
          formatRespBody = apiCaller.parseRespBody()
          fileIsAscii = (formatRespBody['data']['text'] == 'ascii')
        else
          fileIsAscii = false
        end
        # also check file size
        apiCaller.setRsrcPath("#{uriObj.path}/size?")
        apiCaller.get()
        if(apiCaller.succeeded?)
          sizeRespBody = apiCaller.parseRespBody()
          fileSize = formatRespBody['data']['number'].to_i
        else
          fileSize = MAX_FILE_SIZE + 1
        end
        if(fileIsAscii and (fileSize <= MAX_FILE_SIZE))
          # give a warning if any samples have names that will cause SeqImporter to crash
          fileContents = ''
          apiCaller.setRsrcPath("#{uriObj.path}/data?")
          apiCaller.get(){ |chunk| fileContents << chunk}
          # become robust to all types of file line endings
          fileContents = fileContents.toUnix()
          # find the header
          nameCol = nil
          headerLine = nil
          warnNames = []
          fileContents.each_line{ |line|
            next unless(line =~ /\S/)
            if(line.index("#"))
              # then this is a header
              headerLine = line
              headerLine.delete("#")
              fieldNames = headerLine.split("\t")
              fieldNames.each_index{ |ii|
                if(fieldNames[ii].downcase().strip() == 'name')
                  nameCol = ii
                  break
                end
              }
            else
              # then this line is a sample record, check its sample name for downstream tool safety
              unless(headerLine.nil? or nameCol.nil?)
                lineTokens = line.split("\t")
                nameToken = lineTokens[nameCol]
                matchResult = nameToken.match(/[^A-Za-z0-9_\.\-\+]/)
                unless(matchResult.nil?)
                  warnNames.push(nameToken)
                end
              else
                # cant process lines without a header
                break
              end
            end
          }
          # make a warning if we could not find the header or if we have found unsafe sample names
          if(headerLine.nil? or nameCol.nil?)
            warningMsg << "We were unable to find a header line indicating a name column in the provided file.\n"
            wbJobEntity.context['wbErrorMsg'] = warningMsg
          end
          unless(warnNames.empty?)
            warningMsg << "The following samples have names that are not supported by the Microbiome Workbench:"
            warningMsg << "<ul>"
            warnNames.each{ |name|
              warningMsg << "<li>#{name}</li>"
            }
            warningMsg << "</ul>"
            warningMsg << "\nPlease click <code>No</code> and rename these samples so that they only include the characters A-Z, a-z, 0-9, ., _, -, or + if you plan to use the Microbiome Workbench."
            wbJobEntity.context['wbErrorMsg'] = warningMsg
            wbJobEntity.context['wbErrorMsgHasHtml'] = true
          else
            sampleNameWarning = false
          end
        else
          # define a warning that states that the samples could not have their format read
          warningMsg = "We could not determine if the samples in your file have names compatible with the Microbiome Workbench probably because your file is compressed or very large. Please note that in the Microbiome Workbench samples names can only include the characters A-Z, a-z, 0-9, ., _, -, or +."
          wbJobEntity.context['wbErrorMsg'] = warningMsg
        end
        # If new sample set provided, give a warning if it already exists
        newSampleSetName = wbJobEntity.settings['sampleSetName']
        @dbu = BRL::Genboree::DBUtil.new(@genbConf.dbrcKey, nil, nil)
        @userId = wbJobEntity.context['userId']
        @hostAuthMap = Abstraction::User.getHostAuthMapForUserId(@dbu, @userId)
        if(!newSampleSetName.nil? and !newSampleSetName.empty?)
          genbConf = BRL::Genboree::GenboreeConfig.load()
          apiDbrc = @superuserApiDbrc
          uri = URI.parse(wbJobEntity.outputs[0])
          rcscUri = "#{uri.path.chomp("?")}/sampleSets?"
          apiCaller = ApiCaller.new(uri.host, rcscUri, @hostAuthMap)
          retVal = ""
          # Making internal API call
          apiCaller.initInternalRequest(@rackEnv, genbConf.machineNameAlias) if(@rackEnv)
          resp = apiCaller.get()
          if(apiCaller.succeeded?)
            retVal = JSON.parse(apiCaller.respBody)
            sampleSetFound = false
            retVal['data'].each { |sampleSet|
              if(sampleSet['name'] == newSampleSetName)
                sampleSetFound = true
                break
              end
            }
            if(sampleSetFound)
              wbJobEntity.context['wbErrorMsg'] = 'A sample set with this name already exists. Continue?'
            else
              sampleSetNameWarning = false
            end
          else
            wbJobEntity.context['wbErrorMsg'] = "API call to get sampleSets failed: #{apiCaller.respBody.inspect}"
          end
        else # nothing to do
          sampleSetNameWarning = false
        end
        warningsExist = (sampleSetNameWarning or sampleNameWarning)
      end

      # Clean up helpers, which cache many things
      @trkApiHelper.clear() if(!@trkApiHelper.nil?)
      @dbApiHelper.clear() if(!@dbApiHelper.nil?)
      return warningsExist
    end
  end
end ; end; end # module BRL ; module Genboree ; module Tools
