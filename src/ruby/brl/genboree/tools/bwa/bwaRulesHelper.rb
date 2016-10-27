require 'brl/genboree/tools/workbenchRulesHelper'
require 'brl/genboree/tools/workbenchFormHelper'
require 'brl/genboree/rest/helpers/trackApiUriHelper'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require 'uri'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/rest/apiCaller'
require "brl/genboree/helpers/sniffer"
require 'tempfile'
include BRL::Genboree::REST

module BRL ; module Genboree ; module Tools
  class BwaRulesHelper < WorkbenchRulesHelper

    TOOL_ID = 'bwa'

    def rulesSatisfied?(wbJobEntity, sectionsToSatisfy=[ :inputs, :outputs, :context, :settings ], toolIdStr=@toolIdStr)
      # Apply basic rules from the rules file (counts, basic types, other simple things)
      rulesSatisfied = super(wbJobEntity, sectionsToSatisfy, toolIdStr)

      if(rulesSatisfied)
        @dbu = BRL::Genboree::DBUtil.new("#{@genbConf.dbrcKey}", nil, nil)
        # Must pass the rest of the checks as well
        rulesSatisfied = false
        inputs = wbJobEntity.inputs
        outputs = wbJobEntity.outputs

        # To find database of the output target
        dbUri = nil
        outputs.each { |output|
          if(@dbApiHelper.extractName(output))
            dbUri = output
            break
          end
        }

        # ------------------------------------------------------------------
        # Check Inputs/Outputs
        # ------------------------------------------------------------------
        userId = wbJobEntity.context['userId']
        apiKey = BRL::Genboree::GenboreeUtil.getSuperuserDbrc(@genbConf, @genbConf.dbrcFile)
        @user = apiKey.user
        @password = apiKey.password
        fileList = []

        # ------------------------------------------------------------------
        # Check 1: Make sure the genome version is currently supported by BWA
        # ------------------------------------------------------------------
        genomesSatisfied = true
        targetDbUriObj = URI.parse(outputs[0])
        apiCaller = ApiCaller.new(targetDbUriObj.host, "#{targetDbUriObj.path}?", @hostAuthMap)
        apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
        apiCaller.get()
        resp = JSON.parse(apiCaller.respBody)['data']
        genomeVersion = resp['version'].decapitalize
        wbJobEntity.settings['genomeVersion'] = genomeVersion
        expandedInputs = inputs.dup
        filesSatisfied = true

        # To make sure all files inside entity list/folder are from same db version
        if(expandedInputs.size == 1 and inputs[0] !~ /\/file\//)
          expInputUri = URI.parse(inputs[0])
          apiCaller = ApiCaller.new(expInputUri.host, expInputUri.path, @hostAuthMap)
          apiCaller.initInternalRequest(@rackEnv, genbConf.machineNameAlias) if(@rackEnv)
          apiCaller.get()
          respInput = JSON.parse(apiCaller.respBody)['data']

          # If input is an entity list or folder, add them to expandedInputs
          # so it can be used by checkDbVersions to ensure all inputs
          # are from same db
          if(expandedInputs[0] =~ /entityList/)
            respInput.each { |file| expandedInputs << file['url'] }
          elsif(@fileApiHelper.extractName(expandedInputs[0]).nil?)
            respInput.each { |file| expandedInputs << file['refs'][BRL::Genboree::REST::Data::DatabaseFileEntity::REFS_KEY] }
          end

          # If total number of inputs including entity list (EL)/folder is
          # less than 2 (1 EL/folder + 1 single-end FASTQ inside that) or
          # more than 3 (1 EL/folder + 2 paired-end FASTQ files)
          # then stop checking any further
          if(expandedInputs.size < 2 or expandedInputs.size > 3)
            filesSatisfied = false
          end
        end # if(expandedInputs.size == 1)

        # If number of files is not satisfied, directly print the error message
        if(!filesSatisfied)
          wbJobEntity.context['wbErrorMsg'] = "INVALID_NUMBER_OF_INPUTS: You can give 1 (single-end) or 2 (paired-end) input FASTQ files or 1 folder/entity list with 1 (single-end) or 2 (paired-end) input FASTQ files."
          rulesSatisfied = false
        # ------------------------------------------------------------------
        # Check 2: Are all the input files (including those inside entity lists or folders)
        # from the same db version?
        # ------------------------------------------------------------------
        # If number of files is correct but files are from different db versions
        elsif(filesSatisfied and !checkDbVersions(expandedInputs + outputs, skipNonDbUris=true))
        # FAILED: No, some versions didn't match
          wbJobEntity.context['wbErrorMsg'] =
           {
             :msg => 'Some files are from a different genome assembly version than other files, or from the output atabase.',
             :type => :versions,
             :info =>
             {
               :inputs =>  @trkApiHelper.dbVersionsHash(expandedInputs),
               :outputs => @dbApiHelper.dbVersionsHash(outputs)
             }
           }
          rulesSatisfied = false
        else
          # ------------------------------------------------------------------
          # Check 3: Make sure the right combination of inputs has been selected
          # ------------------------------------------------------------------
          errorMsg = ""
          fileFormatSatisfied = true
          # For exactly 2 inputs, make sure both are FASTQ files
          if(filesSatisfied and inputs.size == 2)
            inputs.each { |file|
              if(!@fileApiHelper.extractName(file))
                filesSatisfied = false
                errorMsg = "INVALID_INPUT: For 2 inputs, both need to be files. "
                break
              else
                fileName = file
                fileFormatSatisfied = sniffFastqFormat(fileName)
                unless(fileFormatSatisfied)
                  errorMsg = "INVALID_FILE_FORMAT: Input file is not in FASTQ format. Please check the file format."
                  break
                else
                  fileList << fileName
                end
              end # if(!fileName)
            }
          # For only one input (single-end FASTQ file or folder/files entity list with 1 (single-end) or 2 (paired-end) files)
          elsif(filesSatisfied and inputs.size == 1)
            # If input is an entity list
            if(inputs[0] =~ /entityList/)
              respInput.each { |file|
                fileName = file['url']
                fileFormatSatisfied = sniffFastqFormat(fileName)
                unless(fileFormatSatisfied)
                  errorMsg = "INVALID_FILE_FORMAT: Input file is not in FASTQ format. Please check the file format."
                  break
                else
                  fileList << fileName
                end
              }

            # If input is a folder with files
            elsif(@fileApiHelper.extractName(inputs[0]).nil?)
              respInput.each { |file|
                fileName = file['refs'][BRL::Genboree::REST::Data::DatabaseFileEntity::REFS_KEY]
                fileFormatSatisfied = sniffFastqFormat(fileName)
                unless(fileFormatSatisfied)
                  errorMsg = "INVALID_FILE_FORMAT: Input file is not in FASTQ format. Please check the file format."
                  break
                else
                  fileList << fileName
                end
              }

            # If input is a single-end FASTQ file
            elsif(inputs[0] =~ /\/file\//)
              fileName = inputs[0]
              fileFormatSatisfied = sniffFastqFormat(fileName)
              unless(fileFormatSatisfied)
                errorMsg = "INVALID_FILE_FORMAT: Input file is not in FASTQ format. Please check the file format."
                # wbJobEntity.context['wbErrorMsg'] = errorMsg
              else
                fileList << fileName
              end

            # If input does not satisfy any of the above conditions
            else
              filesSatisfied = false
              errorMsg = "INVALID_INPUT: You need to drag 1 (single-end) or 2 (paired-end) input FASTQ files. "
            end
          else
            errorMsg = "INVALID_NUMBER_OF_INPUTS: You can give 1 (single-end) or 2 (paired-end) input FASTQ files or 1 folder/entity list with 1 (single-end) or 2 (paired-end) input FASTQ files. "
          end # if(filesSatisfied and inputs.size == 2)

          unless(fileFormatSatisfied)
            wbJobEntity.context['wbErrorMsg'] = errorMsg
            rulesSatisfied = false
          else
            wbJobEntity.inputs = fileList
            rulesSatisfied = true
          end # unless(fileFormatSatisfied)
        end # if(!filesSatisfied)

        # ------------------------------------------------------------------
        # CHECK SETTINGS
        # ------------------------------------------------------------------
        if(sectionsToSatisfy.include?(:settings))
          # Check :settings together with info from :outputs :
          unless( sectionsToSatisfy.include?(:outputs) and  sectionsToSatisfy.include?(:inputs) )
            raise ArgumentError, "Cannot validate just :settings for this tool without info provided in both :inputs and :outputs."
          end

          rulesSatisfied = true

          # For track settings
          doUploadResults = wbJobEntity.settings['doUploadResults']
          properTrackName = true

          # For BWA index settings
          useIndex = wbJobEntity.settings['useIndex']
          selectedEp = false
          makeNewIndex = false
          error = ""

          # Check1: A job with the same analysis name under the same target db should not exist
          output = @dbApiHelper.extractPureUri(outputs[0])
          uri = URI.parse(output)
          host = uri.host
          rcscUri = uri.path
          rcscUri = rcscUri.chomp("?")
          rcscUri << "/file/BWA/#{CGI.escape(wbJobEntity.settings['analysisName'])}/jobFile.json?"
          apiCaller = ApiCaller.new(host, rcscUri, @hostAuthMap)
          apiCaller.initInternalRequest(@rackEnv, genbConf.machineNameAlias) if(@rackEnv)
          apiCaller.get()
          if(apiCaller.succeeded?) # Failed: job dir already exists
            wbJobEntity.context['wbErrorMsg'] = "A job with the analysis name: #{wbJobEntity.settings['analysisName']} has already been launched before. Please select a different job name."
          else
            if(doUploadResults) # Check 2: If 'doUploadResults' has been checked, the track name should be correctly formatted
              @lffType = wbJobEntity.settings['lffType']
              @lffSubType = wbJobEntity.settings['lffSubType']
              if(@lffType.nil? or @lffType.empty? or @lffType =~ /:/ or @lffType =~ /^\s/ or @lffType =~ /\s$/ or @lffType =~ /\t/)
                error = "INVALID_INPUT: The 'lffType' field is incorrectly formatted"
                properTrackName = false
              end
              if(@lffSubType.nil? or @lffType.empty? or @lffType =~ /:/ or @lffType =~ /^\s/ or @lffType =~ /\s$/ or @lffType =~ /\t/)
                error = "INVALID_INPUT: The 'lffSubType' field is incorrectly formatted"
                properTrackName = false
              end
              unless(properTrackName)
                wbJobEntity.context['wbErrorMsg'] = error
                rulesSatisfied = false
              else
                rulesSatisfied = true
              end # unless(properTrackName)
            end
            if(rulesSatisfied and useIndex =~ /makeNewIndex/) # Check 3: Index BWA settings for entry points. Atleast one entry point must be selected
              settings =  wbJobEntity.settings
              baseWidget =  settings['baseWidget']
              makeNewIndex = true
              settings.keys.each{ |key|
                if(key =~ /#{baseWidget}/)
                  selectedEp = true
                  break
                end
              }
              if(makeNewIndex && !selectedEp)
                errorMsg = "INVALID SELECTION: You should select at least one entrypoint to make a custom BWA index."
                wbJobEntity.context['wbErrorMsg'] = errorMsg
                rulesSatisfied = false
              else
                rulesSatisfied = true
              end
            end
            if(rulesSatisfied)# Check 4:  Check entry for bwa specific settings
              bwaSettingsSatisfied = true
              presetOption = wbJobEntity.settings['presetOption']
              if(presetOption =~ /mem/)
                bwaSettings = ["bandWidth", "matchScore", "minSeedLength", "xDropoff", "outAlignment"]
                unless(wbJobEntity.settings['bandWidth'] =~ /^\d+$/)
                  error = "INVALID_INPUT: The bandwidth field is incorrectly formatted. The field can contain only a positive integer."
                  bwaSettingsSatisfied = false
                end
              elsif(presetOption =~ /aln/)
                bwaSettings = ["numGapOpens", "disDeletion", "disIndel", "maxEditSeed", "maxNumAlignments"]
                unless(wbJobEntity.settings['matchPenalty'] =~ /^\d+$/)
                  error = "INVALID_INPUT: The Match Penalty is incorrectly formatted. The field can contain only a positive integer."
                  bwaSettingsSatisfied = false
                end
              else
                bwaSettings = ["bandWidth", "matchScore"]
              end
              bwaSettings.each {|entry|
                bwaOption = wbJobEntity.settings[entry]
                unless(bwaOption =~ /^-?\d+$/)
                  error = "INVALID_INPUT: The #{entry} field is incorrectly formatted. The field cannot contain alphabets, wild characters or left empty."
                  bwaSettingsSatisfied = false
                end
              }
              unless(bwaSettingsSatisfied)
                wbJobEntity.context['wbErrorMsg'] = error
                rulesSatisfied = false
              else
                rulesSatisfied = true
              end
            end

          end # if(apiCaller.succeeded?)
        end # if(sectionsToSatisfy.include?(:settings))
      end # if(rulesSatisfied)
      return rulesSatisfied
    end

    # Sniffer for FASTQ
    def sniffFastqFormat(fileName)
      fileFormatSatisfied = true
      fileUriObj = URI.parse(fileName)
      apiCaller = ApiCaller.new(fileUriObj.host, "#{fileUriObj.path}/type?", @hostAuthMap)
      apiCaller.initInternalRequest(@rackEnv, genbConf.machineNameAlias) if(@rackEnv)
      apiCaller.get()
      type = JSON.parse(apiCaller.respBody)['data']['text']
      if(type != 'text')
        fileFormatSatisfied = true # Since file is not text, assume format is true and check if file is FASTQ in the wrapper
        return fileFormatSatisfied
      else
        # To check FASTQ format if file is not compressed
        sniffer = BRL::Genboree::Helpers::Sniffer.new()
        # Get number of records needed by Sniffer
        numRecs = sniffer.getFormatConf('fastq').nRecs
        apiCaller = ApiCaller.new(fileUriObj.host, "#{fileUriObj.path}/data?", @hostAuthMap)
        apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
        tmpFileName = "#{Time.now.to_f}.#{rand(10_000)}.#{CGI.escape(File.basename(@fileApiHelper.extractName(fileName)))}"
        # Make Tempfile. Auto-cleaned up when we call close. Use untainted Dir::tmpdir as a best practice.
        tempFastqFileObj  = Tempfile.new(tmpFileName, Dir::tmpdir.untaint)
        numLines = 0
        apiCaller.get() { |chunk|
          tempFastqFileObj.print(chunk)
          numLines += chunk.count("\n")
          break if(numLines >= numRecs)
        }
        tempFastqFileObj.flush()
        # tempFastqFileObj.path gives the entire path and file name
        sniffer.filePath = tempFastqFileObj.path
        if(!sniffer.detect?('fastq'))
          fileFormatSatisfied = false
        end
        tempFastqFileObj.close()
        tempFastqFileObj.unlink()
      end
      return fileFormatSatisfied
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
        useIndex = wbJobEntity.settings['useIndex']
        if(useIndex =~ /makeNewIndex/)
          outputs = wbJobEntity.outputs
          output = @dbApiHelper.extractPureUri(outputs[0])
          uri = URI.parse(output)
          host = uri.host
          rcscUri = uri.path
          rcscUri = rcscUri.chomp("?")
          output.gsub!(/\?$/, '')
          apiCaller = ApiCaller.new(host, rcscUri, @hostAuthMap)
          apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
          apiCaller.get()
          resp = JSON.parse(apiCaller.respBody)['data']
          genomeVersion = resp['version'].decapitalize
          @indexBaseName =  CGI.escape(wbJobEntity.settings['indexBaseName'])
          @outputIndexFile = "#{@indexBaseName}.tar.gz"
          filePath = "#{output}/file/indexFiles/BWA/#{@indexBaseName}/#{CGI.escape(@outputIndexFile)}?"

          ## Look for index in user db or repository db
          if(@fileApiHelper.exists?(filePath, @hostAuthMap))
            ## Index found in user db
            errorMsg = "Bwa Index with same name <b>#{@outputIndexFile}</b> is available in user DB <b>#{CGI.unescape(output)} </b>. Do you want to replace this index? "
            warnings = true
          else
            @roiRepositoryGroup = @genbConf.roiRepositoryGrp
            @roiRepoDb = "#{@roiRepositoryGroup}#{genomeVersion}"
            indexUri = URI.parse(@roiRepoDb)
            rsrcPath = indexUri.path
            @roiDirs = ['wholeGenome', 'eachChr']
            @roiDirs.each { |dirName|
              apiCaller = ApiCaller.new(indexUri.host, "#{rsrcPath}/files/indexFiles/BWA/#{CGI.escape(dirName)}/#{CGI.escape(@outputIndexFile)}", @hostAuthMap)
              apiCaller.get()
              if(apiCaller.succeeded?)
                ## The index is available in common database
                errorMsg = "BWA Index with name <b>#{@outputIndexFile}</b> is available in repository DB <b>#{CGI.unescape(@roiRepoDb)}</b>. You may consider using the existing index or create a
new index in your database with the same name.<br> Do you want to continue building the index?"
                warnings = true
              end # if(apiCaller.succeeded?)
            }
          end
        end
        if(warnings)
          wbJobEntity.context['wbErrorMsg'] = errorMsg
          wbJobEntity.context['wbErrorMsgHasHtml'] = true
        else
          warningsExist = false
        end
        $stderr.puts "SETTINGS: #{wbJobEntity.settings.inspect}"
      end
      # Clean up helpers, which cache many things
      @trkApiHelper.clear() if(!@trkApiHelper.nil?)
      @dbApiHelper.clear() if(!@dbApiHelper.nil?)
      return warningsExist
    end
  end
end ; end; end # module BRL ; module Genboree ; module Tools
