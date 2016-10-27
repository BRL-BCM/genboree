require 'brl/genboree/tools/workbenchRulesHelper'
require 'brl/genboree/tools/workbenchFormHelper'
require 'brl/genboree/rest/helpers/trackApiUriHelper'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require 'brl/genboree/rest/helpers/groupApiUriHelper'
require 'brl/genboree/genboreeUtil'
require 'brl/util/expander'
require 'brl/util/convertText'
require 'brl/genboree/rest/apiCaller'

module BRL ; module Genboree ; module Tools
  class MachineLearningManualRulesHelper < WorkbenchRulesHelper

    TOOL_ID = 'machineLearningManual'

    def rulesSatisfied?(wbJobEntity, sectionsToSatisfy=[ :inputs, :outputs, :context, :settings ], toolIdStr=@toolIdStr)
      # Apply basic rules from the rules file (counts, basic types, other simple things)
      rulesSatisfied = super(wbJobEntity, sectionsToSatisfy, toolIdStr)

      if(rulesSatisfied)
        tempFileObj = nil
        exp = nil
        @dbu = BRL::Genboree::DBUtil.new("#{@genbConf.dbrcKey}", nil, nil)
        outputs = wbJobEntity.outputs
        inputs = wbJobEntity.inputs
        userId = wbJobEntity.context['userId']
        # Perform validation:
        opsList = []
        killList = @genbConf.microbiomeKillList
        # If inputs size == 2 and both are files, make sure there are at least 3 samples in the samples file
        if(inputs.size == 2 and inputs[0] =~ BRL::Genboree::REST::Helpers::FileApiUriHelper::NAME_EXTRACTOR_REGEXP and inputs[1] =~ BRL::Genboree::REST::Helpers::FileApiUriHelper::NAME_EXTRACTOR_REGEXP)
          uri = URI.parse(inputs[1]) # Assume second file is samples file
          rcscPath = uri.path
          rcscPath = uri.path.chomp("?")
          rcscPath << "/data?"
          apiCaller = ApiCaller.new(uri.host, rcscPath, @hostAuthMap)
          # Do internal request if enabled (in this case, if we've been given a Rack env hash to work from)
          retVal = ""
          apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
          resp = apiCaller.get()
          if(apiCaller.succeeded?)
            retVal = apiCaller.respBody
          else
            $stderr.puts "ERROR: apiCaller to get features failed. resp body:\n#{apiCaller.respBody.inspect}"
          end
          tmpFileName = "#{Time.now().to_f}.txt__"
          # Make Tempfile. Auto-cleaned up when we call close. Use untained Dir::tmpdir as a best practice.
          # - Don't close until all done with the file!
          tempFileObj  = Tempfile.new(tmpFileName, Dir::tmpdir.untaint)
          tempFileObj.write(retVal)
          tempFileObj.flush() # ensure contents written to disk...will be reading from disk before we're done with the Tempfile!
          # tempFileObj.path gives full path to temp file
          exp = BRL::Util::Expander.new(tempFileObj.path)
          exp.extract()
          if(exp.uncompressedFileName != tempFileObj.path)
            `mv #{exp.uncompressedFileName} #{tempFileObj.path}`
          end
          convObj = BRL::Util::ConvertText.new(tempFileObj.path, true)
          convObj.convertText()
          # Regardless of whether expansion or conversion was necessary, tempFileObj.path should have the correct content
          retVal = File.read(tempFileObj.path)
          # Done with tempFileObj. We have what we need, allow it to be cleaned up
          tempFileObj.close() rescue nil
          # Process contents:
          buffIO = StringIO.new(retVal)
          featureLine = buffIO.readline
          featureLine.gsub!("#", "")
          features = featureLine.chomp.split(/\t/)
          featureIndexHash = {}
          features.size.times { |featureIndex|
            featureIndexHash[features[featureIndex]] = featureIndex
          }
          features.uniq!
          # Check that there are at least 3 unique 'name' records
          names = []
          sampleNames = []
          buffIO.each_line { |line|
            columns = line.split(/\t/)
            names.push(columns[featureIndexHash['name']]) if(featureIndexHash.has_key?('name'))
            sampleNames.push(columns[featureIndexHash['sampleName']]) if(featureIndexHash.has_key?('sampleName'))
          }
          if(sampleNames.uniq.size < 3 and names.uniq.size < 3)
            wbJobEntity.context['wbErrorMsg'] = "Precondition Failed: MISSING_VALUES: There MUST be at least 3 unique samples (3 unique records for 'name' OR 'sampleName' column) in the samples file to run this tool."
            rulesSatisfied = false
          end
          # Get kill list
          if(rulesSatisfied)
            buffIO.rewind()
            if(!features.nil? and !features.empty?)
              tempList = features - killList
              featureHash = {}
              tempList.each { |feature|
                featureHash[feature] = {}
              }
              # Now pick out only those features that have at least 2 unique records
              buffIO.readline
              buffIO.each_line { |line|
                records = line.chomp.split(/\t/)
                featureHash.each_key { |feature|
                  featureHash[feature][records[featureIndexHash[feature]]] = nil
                }
              }
              featureHash.each_key { |feature|
                opsList.push(feature) if(featureHash[feature].keys.size > 1)
              }
            end
          end
        end

        if(rulesSatisfied)
          # Check the number of 'dragged' samples. Must be at least 3 or 0
          bioSamples = 0
          bioSampleNames = {}
          inputs.each { |input|
            if(input !~ BRL::Genboree::REST::Helpers::FileApiUriHelper::NAME_EXTRACTOR_REGEXP)
              bioSamples += 1
              bioSampleNames[input] = @sampleApiUriHelper.extractName(input)
            end
          }
          if(bioSamples > 0 and bioSamples < 3)
            wbJobEntity.context['wbErrorMsg'] = "Precondition Failed: MISSING_VALUES: You MUST drag be at least 3 samples or drag a samples file(with at least 3 unique samples) to run this tool"
            rulesSatisfied = false
          end
          if(rulesSatisfied)
            # If we do have 3 or more bioSamples, we need to do the same validation we did for samples file, i.e, check (after subtracting the kill list)
            # that there are at least 2 unique values for at least one feature (to show in the metadata features widget)
            if(bioSamples >= 3)
              featureHash = {}
              prevDb = nil
              dataArray = []
              bioSampleNames.each_key { |sampleUri|
                dbUri = @dbApiHelper.extractPureUri(sampleUri)
                if(prevDb.nil? or prevDb != dbUri)
                  # Get all samples in the db:
                  uri = URI.parse(dbUri)
                  rcscPath = uri.path
                  rcscPath = rcscPath.chomp("?")
                  rcscPath << "/bioSamples?detailed=true"
                  apiCaller = ApiCaller.new(uri.host, rcscPath, @hostAuthMap)
                  retVal = ""
                  apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
                  resp = apiCaller.get()
                  if(apiCaller.succeeded?)
                    retVal = apiCaller.respBody
                  else
                    wbJobEntity.context['wbErrorMsg'] = "ERROR: apiCaller to get bioSamples failed. resp body:\n#{apiCaller.respBody.inspect}"
                    rulesSatisfied = false
                  end
                  retHash = JSON.parse(retVal)
                  dataArray = retHash['data']
                end

                # Go through array and collect field values for the required sample
                avpsHash = {}
                dataArray.each { |sample|
                  if(sample['name'] == bioSampleNames[sampleUri])
                    avpsHash = sample['avpHash']
                    break
                  end
                }
                tempList = avpsHash.keys - killList
                tempList.each { |feature|
                  featureHash[feature] = {} if(!featureHash.has_key?(feature))
                  featureHash[feature][avpsHash[feature]] = nil
                }
                prevDb = dbUri
              }
              featureHash.each_key { |feature|
                opsList.push(feature) if(featureHash[feature].keys.size > 1)
              }
            end
            if(opsList.empty?)
              wbJobEntity.context['wbErrorMsg'] = "Precondition Failed: MISSING_VALUES: There MUST be at least 2 unique values for at least one feature to run Machine Learning"
              rulesSatisfied = false
            else
              wbJobEntity.settings['opsList'] = opsList
              buffIO.close if(buffIO)
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
          # Check #1: Make sure at least one feature is selected from the feature list:
          featureList = wbJobEntity.settings['featureList']
          if(featureList.nil? or featureList.empty?) # Failed if none selected
            wbJobEntity.context['wbErrorMsg'] = "Bad Request: You must select at least one feature from the feature list"
          else
            # Check 2: does the dob dir already exist?
            uri = URI.parse(outputs[0])
            host = uri.host
            rcscUri = uri.path
            rcscUri = rcscUri.chomp("?")
            rcscUri << "/file/MicrobiomeWorkBench/#{CGI.escape(wbJobEntity.settings['studyName'])}/MachineLearning/#{CGI.escape(wbJobEntity.settings['jobName'])}/jobFile.json?"
            apiCaller = ApiCaller.new(host, rcscUri, @hostAuthMap)
            apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
            apiCaller.get()
            if(apiCaller.succeeded?) # Failed: job dir already exists
              wbJobEntity.context['wbErrorMsg'] = "A job with the job name: #{wbJobEntity.settings['jobName']} has already been launched before for the study: #{wbJobEntity.settings['studyName']}. Please select a different job name."
            else
              rulesSatisfied = true
            end
          end
        end
        # Clean up. Remove tempfile (via close) and any subdir the Expander used
        `rm -rf #{exp.tmpDir}`
        tempFileObj.close() rescue nil
      end
        # ------------------------------------------------------------------
        # CHECK SETTINGS
        # ------------------------------------------------------------------

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
