require 'brl/genboree/tools/workbenchJobHelper'
require 'brl/genboree/rest/helpers/kbApiUriHelper'
require 'brl/genboree/kb/propSelector'
require 'brl/genboree/kb/helpers/modelsHelper'
require 'brl/genboree/kb/transformers/transformedDocHelper'

module BRL; module Genboree; module Tools
  class ReasonerJobHelper < WorkbenchJobHelper
    TOOL_ID = "reasoner"

    TRANSFORM_PARAM = "transform"
    FORMAT_PARAM = "format"
    FORMAT_VALUE = "json"
    
    R_MODULE_NAME = "R"
    R_VERSION = "3.1"

    MODULE_NAME = "Reasoner"
    MODULE_VERSION = "1.0"
    CONCLUDER_NAME = "Reasoner"
    CMD_NAME = "Reasoner.R"

    # Extract information from stdout/stderr
    # @todo this is unique to reasoner1
    # Providing this information as a set of variables that should be easily modified if the 
    #   script changes its output style; pattern must have $1 match group as the information
    #   to be retrieved and used by the wrapper
    # Assertions are presented e.g.
    #   Assertion => LikelyPathogenic , Pathogenic , LikelyPathogenic , Benign , LikelyBenign
    #   ReasonForAssertion => Pathogenic.Moderate >=3 , Pathogenic.Strong >=2 , Pathogenic.Moderate 
    #   >=1 & Pathogenic.Supporting >=4 , Benign.Strong >=2 , Benign.Supporting >=2
    # Warning messages are presented e.g.
    #   "Warning Name => Guidelines Parse Warning."
    #   "Warning Message => The last column is not named Inference"
    # Error messages are presented e.g.
    #   "Error: Error Name => Evidence Parse Error."
    #   "Error Message => One or More of evidence tags that you supplied are not known to provided Guidelines! They are listed here: \"Pathogenic.Very Not Strong\"."
    ASSERTION_DELIM = REASON_DELIM = WARNING_DELIM = ERROR_DELIM = "\\s*=>\\s*"
    ASSERTION_ITEM_DELIM = ","
    ASSERTION_PREFIX = "Assertion"
    ASSERTION_PATTERN = %r{#{ASSERTION_PREFIX}#{ASSERTION_DELIM}(.*)$}

    REASON_ITEM_DELIM = ","
    REASON_PREFIX = "ReasonForAssertion"
    REASON_PATTERN = %r{#{REASON_PREFIX}#{REASON_DELIM}(.*)$}

    WARNING_NAME_PREFIX = "Warning Name"
    WARNING_MESSAGE_PREFIX = "Warning Message"
    WARNING_NAME_PATTERN = %r{#{WARNING_NAME_PREFIX}#{WARNING_DELIM}(.*)$}
    WARNING_MESSAGE_PATTERN = %r{#{WARNING_MESSAGE_PREFIX}#{WARNING_DELIM}(.*)$}

    ERROR_NAME_PREFIX = "Error Name"
    ERROR_MESSAGE_PREFIX = "Error Message"
    ERROR_NAME_PATTERN = %r{#{ERROR_NAME_PREFIX}#{ERROR_DELIM}(.*)$}
    ERROR_MESSAGE_PATTERN = %r{#{ERROR_MESSAGE_PREFIX}#{ERROR_DELIM}(.*)$}

    def initialize(toolIdStr, genbConf=nil, dbu=nil, *args)
      super(toolIdStr, genbConf, dbu, args)
      @kbApiUriHelper = BRL::Genboree::REST::Helpers::KbApiUriHelper.new(dbu, genbConf)
      cmds = [
        "module load #{MODULE_NAME}/#{self.class::MODULE_VERSION}",
        "unset R_HOME"
      ]
      @reasonerCmdPrefix = "#{cmds.join(" ; ")} ; #{CMD_NAME}"
      @adminMsg = "Please contact the administator at #{@genbConf.send(:gbAdminEmail)}." rescue nil
    end

    # Override parent runInProcess() so that we can run on the web server
    # @return [Boolean] whether or not job succeeded
    # @set @workbenchJobObj.results with a Conclusion document
    # @set @workbenchJobObj.context['wbErrorMsg'] if error occurs
    # @todo @workbenchJobObj.settings['updateDoc']
    # @todo would like to put @apiCaller setup in initialize but user authentication hasnt happened at that stage:
    #   it happens with executionCallback is called from the toolJob resource, which in turn executes this function
    def runInProcess()
      success = false
      @apiCaller = BRL::Genboree::REST::WrapperApiCaller.new("", "", @userId) 
      begin
        # fill in conclusion doc as we go
        # @todo conclusionDoc only needed for reasoner1
        conclusionDoc = getConclusionTemplate() # @todo use generic doc template from model
        conclusionDoc.setPropVal("Conclusion.Concluder", CONCLUDER_NAME)

        rulesDocUrl = @workbenchJobObj.settings["rulesDoc"]
        conclusionDoc.setPropVal("Conclusion.Guidelines", rulesDocUrl)
        rulesDoc = getRulesDoc(rulesDocUrl, @apiCaller)

        # construct transformation URL based on inputs
        # use first input of each type (if there are multiple inputs of the same type)
        type2Input = classifyInputs(@workbenchJobObj.inputs)
  
        # kbDoc is available, get the latest version for timestamp
        # @todo perhaps once GET on kbDocProp is finished we can get JUST the timestamp
        timeObj = getInputDocTimestamp(type2Input[:kbDoc], @apiCaller)
        conclusionDoc.setPropVal("Conclusion.TimeStampOfDocument", timeObj)
 
        # then no errors, apply kb transform to kb doc 
        transformDoc = transformDocument(type2Input[:kbDoc], type2Input[:kbTransform], @apiCaller)
  
        # with the transform and rules docs, extract the data necessary for Reasoner
        # build guildlines tsv string
        # @todo reasoner2 needs evidence and meta from guidelines
        guidelines = parseGuidelines(rulesDoc)
        guidelinesTsv = self.class.hashToCsv(guidelines, "\t")
  
        evidence = parseEvidence(guidelines, transformDoc)
        evidenceCsv = formatEvidence(evidence)
  
        # run Reasoner
        # @todo what if module load part fails? pray
        guidelinesTsv.gsub!("\t", "\\t")
        guidelinesTsv.gsub!("\n", "\\n")
        cmd = @reasonerCmdPrefix + " \"#{guidelinesTsv}\" " + " \"#{evidenceCsv}\" "
        cmdStatus, stdout, stderr = BRL::Util::popen4Wrapper(cmd)
        assertions = warningName = warningMsg = errorName = errorMsg = nil
        if(cmdStatus.exitstatus == 0)
          success = true
          # check for warnings
          # @todo reasoner2 has no warnings or assertions to parse
          warningName, warningMsg = checkWarning(stderr)
          assertions = parseAssertions(stdout)
          if(assertions.empty?)
            # success and no assertions is a bug
            raise ReasonerJobError.new("Could not parse assertions from #{CMD_NAME}. #{@adminMsg}", :"Internal Server Error")
          end
          conclusionAssertions = []
          assertions.each_index { |ii|
            assertionDoc = BRL::Genboree::KB::KbDoc.new()
            assertionDoc.setPropVal("Assertion", "Assertion-#{ii}")
            assertionDoc.setPropProperties("Assertion", assertions[ii])
            conclusionAssertions.push(assertionDoc)
          }
          conclusionDoc.setPropItems("Conclusion.Assertions", conclusionAssertions)
        else
          success = false
          # check for warning, error
          warningName, warningMsg = checkWarning(stderr)
          errorName, errorMsg = checkError(stderr)
        end

        # fill in Conclusion document with cmd information
        status = name = message = nil
        if(!errorName.nil? or !errorMsg.nil?)
          status = "error"
          name = errorName
          message = errorMsg
        elsif(!warningName.nil? or !warningMsg.nil?)
          status = "warning"
          name = warningName
          message = warningMsg
        else
          status = "ok"
          name = "ok"
          message = "ok"
        end
        conclusionDoc.setPropVal("Conclusion.Status", status)
        conclusionDoc.setPropVal("Conclusion.Status.Name", name)
        conclusionDoc.setPropVal("Conclusion.Status.Message", message)

        # finally, the timestamp when we are done
        conclusionDoc.setPropVal("Conclusion.TimeStampOfConclusion", Time.now.to_s)
        @workbenchJobObj.results = conclusionDoc

        # @todo re upload document on success
      rescue => err
        logAndPrepareError(err)
        success = false
      end
      
      return success
    end

    # @note if @rackEnv is set @genbConf must be set
    def getRulesDoc(rulesDocUrl, apiCaller=@apiCaller)
      # retrieve rules doc, validated by rulesHelper
      uriObj = URI.parse(rulesDocUrl)
      apiCaller.setHost(uriObj.host)
      apiCaller.setRsrcPath("#{uriObj.path}?#{uriObj.query}")
      apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
      resp = apiCaller.get()
      unless(apiCaller.succeeded?)
        parsedBody = apiCaller.parseRespBody() rescue nil
        msg = parsedBody.respond_to?(:getNestedAttr) ? parsedBody.getNestedAttr("status.msg") : nil
        code = parsedBody.respond_to?(:getNestedAttr) ? parsedBody.getNestedAttr("status.statusCode") : nil
        code = (code.nil? ? :"Internal Server Error" : code.to_sym)
        raise ReasonerJobError.new("Unable to retrieve rulesDoc #{rulesDocUrl.inspect} ; Status message: #{msg.inspect}", code)
      end
      rulesDoc = apiCaller.parseRespBody()['data']
      return rulesDoc
    end

    # @note @kbApiUriHelper must be set
    def classifyInputs(inputs)
      type2Input = {}
      inputs.each{ |input|
        type = @kbApiUriHelper.classifyUri(input)
        if(!type.nil? and !type2Input.key?(type))
          type2Input[type] = input
        end
      }
      unless(type2Input[:kbDoc] and type2Input[:kbTransform])
        # this is redundant with workbench.rules.json and reasonerRulesHelper
        missingType = (type2Input.key?(:kbDoc) ? :kbDoc : :kbTransform)
        raise ReasonerJobError.new("Missing an input of type #{missingType}; this tool requires a kbDoc and a kbTransform", :"Bad Request")
      end
      return type2Input
    end

    # @todo perhaps once GET on kbDocProp is finished we can get JUST the timestamp
    def getInputDocTimestamp(kbDocUrl, apiCaller=@apiCaller)
      uriObj = URI.parse(kbDocUrl)
      kbDocVersionPath = "#{uriObj.path.chomp("/")}/ver/HEAD"
      apiCaller.setHost(uriObj.host)
      apiCaller.setRsrcPath(kbDocVersionPath)
      apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
      resp = apiCaller.get()
      unless(apiCaller.succeeded?)
        parsedBody = apiCaller.parseRespBody() rescue nil
        msg = parsedBody.respond_to?(:getNestedAttr) ? parsedBody.getNestedAttr("status.msg") : nil
        code = parsedBody.respond_to?(:getNestedAttr) ? parsedBody.getNestedAttr("status.statusCode") : nil
        code = (code.nil? ? :"Internal Server Error" : code.to_sym)
        raise ReasonerJobError.new("Could not retrieve head version of #{kbDocUrl} for its timestamp ; Status message: #{msg.inspect}", code)
      end
      respBody = apiCaller.parseRespBody()['data']
      timestamp = respBody['versionNum']['properties']['timestamp']['value']
      timeObj = Time.rfc2822(timestamp) rescue nil
      if(timeObj.nil?)
        $stderr.debugPuts(__FILE__, __method__, "ERROR", "Timestamp from version document not parsable according to rfc2822: #{timestamp.inspect}")
        raise ReasonerJobError.new("Could not retrieve valid timestamp from version document #{apiCaller.fillApiUriTemplate.inspect}", :"Internal Server Error")
      end
      return timeObj
    end

    # Transform a KB document through the HTTP API
    # @param [String] kbDocUrl the document to transform
    # @param [String] transformDocUrl URL to document describing to transform it
    # @param [BRL::Genboree::REST::ApiCaller] apiCaller the object used to make the HTTP request
    # @return [Hash] the transformed document
    def transformDocument(kbDocUrl, transformDocUrl, apiCaller=@apiCaller)
      escapedTransform = CGI.escape(transformDocUrl)
      uriObj = URI.parse(kbDocUrl)
      url = "#{uriObj.scheme}://#{uriObj.host}#{uriObj.path}?#{TRANSFORM_PARAM}=#{escapedTransform}&#{FORMAT_PARAM}=#{FORMAT_VALUE}"

      uriObj = URI.parse(url)
      apiCaller.setHost(uriObj.host)
      apiCaller.setRsrcPath("#{uriObj.path}?#{uriObj.query}")
      apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
      resp = apiCaller.get()
      unless(apiCaller.succeeded?)
        parsedBody = apiCaller.parseRespBody() rescue nil
        msg = parsedBody.respond_to?(:getNestedAttr) ? parsedBody.getNestedAttr("status.msg") : nil
        code = parsedBody.respond_to?(:getNestedAttr) ? parsedBody.getNestedAttr("status.statusCode") : nil
        code = (code.nil? ? :"Internal Server Error" : code.to_sym)
        raise ReasonerJobError.new("Could not retrieve transformation via #{url.inspect} ; Status message: #{msg.inspect}", code)
      end
      transformDoc = apiCaller.parseRespBody()['data'] # the actual response is wrapped
      return transformDoc
    end

    # Represent evidence as comma-separated A=V pairs for strictly positive evidences
    # @param [Hash] evidence @see parseEvidence with at least one strictly positive value
    # @return [String] formatted evidence for use by the Reasoner
    def formatEvidence(evidence)
      evidenceCopy = evidence.deep_clone()
      evidenceCopy = evidenceCopy.delete_if { |kk, vv| vv <= 0 }
      if(evidenceCopy.empty?)
        # should have already errored in parse stage
        raise ReasonerJobError.new("Could not format evidence #{evidence.inspect} for #{CMD_NAME} because no evidence value is strictly positive", :"Internal Server Error")
      end
      evidenceArray = evidenceCopy.collect { |kk, vv| "#{kk}=#{vv}" }
      return evidenceArray.join(",")
    end

    # @param [Hash] guidelines @see parseGuidelines
    # @param [Hash] transformDoc the results of applying the transform to the data document
    # @return [Hash] association of PartitionPath paths with some metric applied by the
    #   transform (sum, count, etc.)
    def parseEvidence(guidelines, transformDoc, aggregationRule=nil)
      partitionPaths = guidelines[:header].deep_clone()
      partitionPaths.delete("Guidelines")
      partitionPaths.delete("Inference")

      if(partitionPaths.empty?)
        raise ReasonerJobError.new("No partition paths to count evidence for! Verify the guidelines document.", :"Bad Request")
      end

      pathToCount = {}
      partitionPaths.each{ |partitionPath|
        count = BRL::Genboree::KB::Transformers::TransformedDocHelper.getCountForPath(transformDoc, partitionPath, :op => "sum") # override count to sum
        if(count == :no_path)
          count = 0
          pathToCount[partitionPath] = count
        elsif(count == :no_count)
          raise ReasonerJobError.new("Could not determine the evidence belonging to #{partitionPath.inspect}. #{@adminMsg}", :"Internal Server Error")
        else
          pathToCount[partitionPath] = count
        end
      }

      anyEvidence = false
      pathToCount.each_key { |kk| 
        vv = pathToCount[kk]
        anyEvidence = (anyEvidence || (vv > 0)) 
      }
      unless(anyEvidence)
        raise ReasonerJobError.new("Could not parse any evidence from the transformation document with the given guidelines. Please verify that the transformation document and the resulting transformed data document match your guidelines.", :"Bad Request")
      end

      return pathToCount
    end

    # The Reasoner's first argument is a tsv file as a string describing conditions on properties
    # required to make an assertion, construct this file from the rulesDoc
    # @note rulesDoc refers to a single KB document with ALL the rules for the Reasoner
    #   ruleDocs refer to individual sub documents rooted at a particular rule of the rulesDoc
    # @todo "Guidelines" "Inference", other strings
    # @todo how does the property selector communicate errors? handle those
    # @param [Hash] rulesDoc a previously validated rules document (@see getRulesModel())
    # @return [Hash] with keys
    #   [Array<String>] :header fields that can be used in order for a TSV file
    #   [Hash<String, Hash>>] :data association of a guideline to the relevant data for the Reasoner:
    #     a sub-hash mapping a partitionPath to a condition and an associated inference if
    #     the combined condition is met
    def parseGuidelines(rulesDoc)
      guidelines = { :header => [], :data => {} }
      # documents are assumed to have a single root
      docId = rulesDoc.keys.first

      # extract header data for tsv file
      header = {}
      rulesPropSelector = BRL::Genboree::KB::PropSelector.new(rulesDoc)
      path = "<>.Rules.[].Rule.Conditions.[].Condition.PartitionPath"
      partitionPaths = nil
      begin
        partitionPaths = rulesPropSelector.getMultiPropValues(path)
      rescue RuntimeError, ArgumentError => err
        # document is assumed to be valid, error of this type is a bug
        raise ReasonerJobError.new("Could not retrieve conditions from the rules document. #{@adminMsg}")
      end
      partitionPaths.each{ |partitionPath|
        header[partitionPath] = nil
      }
      header["Guidelines"] = nil
      header["Inference"] = nil

      # order is not required except for inference last but this is a nice layout
      columnOrder = ["Guidelines"]
      keys = header.keys
      keys.delete("Guidelines")
      keys.delete("Inference")
      keys.sort!()
      columnOrder += keys
      columnOrder.push("Inference")
      guidelines[:header] = columnOrder

      # extract row data for tsv file
      path = "<>.Rules.[].Rule"
      ruleDocs = nil
      begin
        ruleDocs = rulesPropSelector.getMultiObj(path)
      rescue ArgumentError, RuntimeError => err
        raise ReasonerJobError.new("Could not retrieve rules from the rules document. #{@adminMsg}")
      end
      partitionPathSubPath = "Rule.Conditions.[].Condition.PartitionPath"
      conditionSubPath = "Rule.Conditions.[].Condition.Condition"
      # @todo aggregation is provided in the model but should be handled already by
      #   the transformation document and finished already once we obtain the transformed
      #   result; why is it in this model? it belongs in the transform instead. is this an override?
      aggregationSubPath = "Rule.Conditions.[].Condition.AggregationOperation"
      inferenceSubPath = "Rule.Inference"
      ruleDocs.each_index { |ii|
        ruleDoc = ruleDocs[ii]
        ruleValue = ruleDoc["Rule"]["value"]
        datum = header.deep_clone()
        datum["Guidelines"] = ruleValue
        rulePropSelector = BRL::Genboree::KB::PropSelector.new(ruleDoc)
        # retrieve parallel arrays
        columns = values = nil
        begin
          columns = rulePropSelector.getMultiPropValues(partitionPathSubPath)
          values = rulePropSelector.getMultiPropValues(conditionSubPath)
        rescue ArgumentError, RuntimeError => err
          raise ReasonerJobError.new("Could not retrieve condition values from the rules document. #{@adminMsg}")
        end
        unless(columns.size == values.size)
          raise ReasonerJobError.new("Could not associate partition path with a condition. #{@adminMsg}")
        end
        columns.each_index { |ii| datum[columns[ii]] = values[ii] }
        datum["Inference"] = rulePropSelector.getMultiPropValues(inferenceSubPath).first
        guidelines[:data][datum["Guidelines"]] = datum
      }

      # @note we assume that since the partitionPathSubPath and path for the header specify the
      #   same elements so that our tsv with at least one row will be a valid one for the Reasoner
      if(guidelines[:data].empty?)
        raise ReasonerJobError.new("Could not retrieve any rules from the rules document. Please verify that rules are present", :"Bad Request")
      end

      return guidelines
    end

    # Parse stdout for assertions
    # @param [String] stdout the stdout from the Reasoner, a pair of padded csv strings,
    #   @see ASSERTION_DELIM
    # @return [Array<Hash>] list of assertion objects
    def parseAssertions(stdout)
      retVal = []
      assertions = reasons = nil
      matchData = REASON_PATTERN.match(stdout)
      unless(matchData.nil?)
        reasons = matchData[1].split(",")
        reasons.map!{|xx| xx.strip()}
      end

      matchData = ASSERTION_PATTERN.match(stdout)
      unless(matchData.nil?)
        assertions = matchData[1].split(",")
        assertions.map!{|xx| xx.strip()}
      end

      if(assertions.size == reasons.size)
        assertions.each_index { |ii|
          assertion = assertions[ii]
          reason = reasons[ii]
          retVal.push( { "Assertion" => { "value" => assertion }, 
                         "ReasonForAssertion" => { "value" => reason } } )
        }
      else
        raise ReasonerJobError.new("Could not associate assertions with reasons for those assertions. #{@adminMsg}")
      end

      return retVal
    end

    # Parse stderr for warning messages
    # @param [String] stderr the stderr from the Reasoner
    # @return [Array<String>] 2-tuple warning name, warning message
    def checkWarning(stderr)
      retVal = [nil, nil]
      warningName, warningMsg = nil
      matchData = WARNING_NAME_PATTERN.match(stderr)
      warningName = matchData[1] unless(matchData.nil?)

      matchData = WARNING_MESSAGE_PATTERN.match(stderr)
      warningMsg = matchData[1] unless(matchData.nil?)

      retVal = [warningName, warningMsg]
      return retVal
    end

    # Parse stderr for error messages
    # @param [String] stderr the stderr from the Reasoner
    # @return [Array<String>] 2-tuple error name, error message
    def checkError(stderr)
      retVal = [nil, nil]
      errorName, errorMsg = nil
      matchData = ERROR_NAME_PATTERN.match(stderr)
      errorName = matchData[1] unless(matchData.nil?)

      matchData = ERROR_MESSAGE_PATTERN.match(stderr)
      errorMsg = matchData[1] unless(matchData.nil?)

      retVal = [errorName, errorMsg]
      return retVal
    end

    # Return a conditions path that can be used for selecting conditions
    #   from the rulesDoc
    # @param [String] docId the document id as provided by the workbench job inputs
    # @todo can prop selector path use {} or <> at root level property? if so, dont 
    #   need this function and can just use "<>" in place of docId
    def getRulePath(docId)
      return "#{docId}.Rules.[].Rule"
    end

    # Return a path that can be used for selecting PartitionPath elements
    #   from a rulesDoc
    # @see getRulePath
    def getPartitionPathPath(docId)
      return "#{docId}.Rules.[].Rule.Conditions.[].Condition.PartitionPath"
    end

    # @todo this is a generic need for kb modelsHelper
    # @note assumes a certain model for a Conclusion document, @see getConclusionModel
    def getConclusionTemplate()
      kbDoc = BRL::Genboree::KB::KbDoc.new()
      kbDoc.setPropVal("Conclusion", "")
      valueHash = { "value" => "" }

      # flat properties
      properties = {
        "TimeStampOfDocument" => valueHash.deep_clone(),
        "TimeStampOfConclusion" => valueHash.deep_clone(),
        "Concluder" => valueHash.deep_clone(),
        "Guidelines" => valueHash.deep_clone(),
      }
      kbDoc.setPropProperties("Conclusion", properties)

      # assertions
      assertion = { "ReasonForAssertion" => valueHash.deep_clone() , "Assertion" => valueHash.deep_clone() }
      kbDoc.setPropItems("Conclusion.Assertions", [assertion])

      # status
      status = { "Name" => valueHash.deep_clone(), "Message" => valueHash.deep_clone() }
      kbDoc.setPropProperties("Conclusion.Status", status)
      return kbDoc
    end
 
    def getConclusionModel()
      model = <<EOS
{
  "name": "Conclusion",
  "domain": "regexp(Conclusion-[A-Z0-9]{20})",
  "required": true,
  "identifier": true,
  "unique": true,
  "properties": [
    {
      "name": "TimeStampOfDocument",
      "domain": "timestamp",
      "required": true
    },
    {
      "name": "TimeStampOfConclusion",
      "domain": "timestamp",
      "required": true
    },
    {
      "name": "Assertions",
      "domain": "[valueless]",
      "fixed": true,
      "items": [
        {
          "name": "Assertion",
          "domain": "regexp(Assertion-[A-Z0-9]{20})",
          "identifier": true,
          "properties": [
            {
              "name": "Assertion",
              "domain": "string",
              "required": true
            },
            {
              "name": "ReasonForAssertion",
              "domain": "string",
              "required": true
            }
          ]
        }
      ]
    },
    {
      "name": "Concluder",
      "domain": "string",
      "required": true
    },
    {
      "name": "Guidelines",
      "domain": "url",
      "required": true
    },
    {
      "name": "Status",
      "domain": "enum(ok, error, warning)",
      "required": true,
      "properties": [
        {
          "name": "Name",
          "domain": "string"
        },
        {
          "name": "Message",
          "domain": "string"
        }
      ]
    }
  ]
}
EOS
    end

    ######################################################################
    # Utility methods                                                    #
    ######################################################################

    # Utility function to transform a hash to a tsv string
    # @param [Hash] hash containing csv data
    #   :header [Array] array with field names in a specified order
    #   :data [Array<Hash>] array of header-like hashes with a row name key mapped to 
    #     column keys mapped to values
    # @param [String] delimiter to use to separate fields/columns
    # @todo associated file version? adding pieces to file chunk by chunk?
    # @todo put this somewhere?
    def self.hashToCsv(hh, delim=",")
      retVal = ""
      retVal << hh[:header].join(delim) << "\n"
      data = hh[:data].collect { |kk, vv| vv }
      data.each { |datum|
        values = hh[:header].map{ |column| datum[column] }
        retVal << values.join(delim) << "\n"
      }
      return retVal
    end
  end

  class ReasonerJobError < WorkbenchJobError
  end
end; end; end
