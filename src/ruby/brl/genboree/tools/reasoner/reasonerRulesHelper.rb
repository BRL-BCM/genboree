
require 'brl/genboree/tools/workbenchRulesHelper'
require 'brl/genboree/rest/helpers/kbApiUriHelper'
require 'brl/genboree/kb/propSelector'
require 'brl/genboree/kb/helpers/modelsHelper'
require 'brl/genboree/kb/transformers/transformer'
require 'brl/genboree/kb/transformers/transformedDocHelper'

module BRL; module Genboree; module Tools
  class  ReasonerRulesHelper < WorkbenchRulesHelper
    TOOL_ID = "reasoner"

    # @todo Fix the sub-standard raise-based return value implementation here. It's using raise to merely communicate message to user
    #   rather than follow standard of setting wbErrorMsg and wbErrorName in context. Makes a mess in the log FOR EXPECTED SITUATIONS and dumps trace
    #   UNNECESSARILY, wasting other dev's time. Reference implementation (workbnechRulesHelper.rb) doesn't follow this java amature
    #   "program by exception" approach and also clearly indicated DO NOT OVERRIDE rulesSatisfied?, use customToolChecks(). And this
    #   is a pretty new bit of code, far newer than customToolChecks().
    #   Poor flow of control here also means raise is used to lots of long-jumps rather than properly if-else nesting which is easier
    #   to peephole optimize by compiler (and less spaghetti flow than this jump-based approach, ugh)
    def rulesSatisfied?(wbJobEntity, sectionsToSatisfy=[ :inputs, :outputs, :context, :settings ], toolIdStr=@toolIdStr)
      retVal = false
      begin
        @kbApiUriHelper = BRL::Genboree::REST::Helpers::KbApiUriHelper.new(@dbu, @genbConf)

        # check access on usual inputs/outputs but also the rulesDoc in the settings
        rulesSatisfied = super(wbJobEntity, sectionsToSatisfy, toolIdStr)
        # UGH, NO. At least the parent class has followed the rules and set wbErrorName/wbErrorMsg.
        # NO NEED TO raise AND MAKE spaghetti long-jumps for normal processing flow.  =>
        #unless(rulesSatisfied)
        # raise BRL::Genboree::GenboreeError.new(:"Forbidden", wbJobEntity.context['wbErrorMsg'])
        #end

        # YES approach. Nested if-else for superior flow analysis and compiler optimization:
        if(rulesSatisfied)
          # rulesDoc must be set by workbench.rules.json
          retVal = testUserPermissions(wbJobEntity.settings["rulesDoc"], 'r')
          unless(retVal)
            # UGH, AGAIN, NO:
            # raise BRL::Genboree::GenboreeError.new(:"Forbidden", "NO READ PERMISSION: You do not have permission to read the rulesDoc #{wbJobEntity.settings["rulesDoc"].inspect}. Please contact the group administrator to arrange read-access.")
            # @todo Fix rest of code (under else below to take  this approach and use nested if-else; not unless-else though)
            wbJobEntity.context['wbErrorName'] = :Forbidden
            wbJobEntity.context['wbErrorMsg'] = "NO READ PERMISSION: You do not have permission to read the rulesDoc #{wbJobEntity.settings["rulesDoc"].inspect}. Please contact the group administrator to arrange read-access."
          else
            # retrieve rules doc
            # validate rulesDoc
            rulesDocUrl = wbJobEntity.settings["rulesDoc"]
            uriObj = URI.parse(rulesDocUrl)
            apiCaller = BRL::Genboree::REST::WrapperApiCaller.new(uriObj.host, "#{uriObj.path}?#{uriObj.query}", @userId)
            apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
            resp = apiCaller.get()
            unless(apiCaller.succeeded?)
              parsedBody = apiCaller.parseRespBody() rescue nil
              msg = (parsedBody and parsedBody['status'] and parsedBody['status']['msg']) rescue nil
              code = (parsedBody and parsedBody['status'] and parsedBody['status']['statusCode']) rescue nil
              code = (code.nil? ? :"Internal Server Error" : code.to_sym)
              raise BRL::Genboree::GenboreeError.new(code, "Unable to retrieve rulesDoc #{rulesDocUrl.inspect} ; Status message: #{msg.inspect}")
            end
            rulesDoc = apiCaller.parseRespBody()['data']
            rulesModel = JSON.parse(getRulesModel())
            kbRulesModel = BRL::Genboree::KB::Helpers::ModelsHelper.getModelTemplate()
            kbRulesModel.setPropVal("name.model", rulesModel)
            docValidator = BRL::Genboree::KB::Validators::DocValidator.new()
            valid = docValidator.validateDoc(rulesDoc, kbRulesModel)
            unless(valid) # true or :CONTENT_NEEDED
              raise BRL::Genboree::GenboreeError.new(:"Bad Request", "The rules document #{rulesDocUrl.inspect} is not a valid rules document for this Reasoner:\n#{docValidator.validationErrors.join("\n")}\n")
            end

            # classify the inputs
            # use first input of each type (if there are multiple inputs of the same type)
            type2Input = {}
            wbJobEntity.inputs.each{ |input|
              type = @kbApiUriHelper.classifyUri(input)
              if(!type.nil? and !type2Input.key?(type))
                type2Input[type] = input
              end
            }
            unless(type2Input[:kbDoc] and type2Input[:kbTransform])
              # this is redundant with workbench.rules.json
              missingType = (type2Input.key?(:kbDoc) ? :kbDoc : :kbTransform)
              raise BRL::Genboree::GenboreeError.new(:"Bad Request", "Missing an input of type #{missingType}; this tool requires a kbDoc and a kbTransform")
            end

            # check if the transformRulesDoc is valid
            # @todo strings..
            kbTransformUrl = type2Input[:kbTransform]
            uriObj = URI.parse(kbTransformUrl)
            apiCaller.setHost(uriObj.host)
            apiCaller.setRsrcPath("#{uriObj.path}?#{uriObj.query}")
            apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
            resp = apiCaller.get()
            unless(apiCaller.succeeded?)
              parsedBody = apiCaller.parseRespBody() rescue nil
              msg = (parsedBody and parsedBody['status'] and parsedBody['status']['msg']) rescue nil
              code = (parsedBody and parsedBody['status'] and parsedBody['status']['statusCode']) rescue nil
              code = (code.nil? ? :"Internal Server Error" : code.to_sym)
              raise BRL::Genboree::GenboreeError.new(code, "Could not retrieve transformation document #{type2Input[:kbTransform]} ; Status message: #{msg.inspect}")
            end
            transformRulesDoc = BRL::Genboree::KB::KbDoc.new(apiCaller.parseRespBody()['data'])
            errMap = {} # path to error
            # Has Transformation.Type value of partitioning
            typePath = "Transformation.Type"
            type = transformRulesDoc.getPropVal(typePath)
            unless(type == "partitioning")
              errMap[typePath] = "#{typePath} must be \"partitioning\""
            end
            # Has Transformation.Scope of doc
            scopePath = "Transformation.Scope"
            scope = transformRulesDoc.getPropVal(scopePath)
            unless(scope == "doc")
              errMap[scopePath] = "#{scopePath} must be \"doc\""
            end
            # Has Transformation.Data.Aggregation.Subject.Type value of int OR float
            aggregationPath = "Transformation.Output.Data.Aggregation.Subject.Type"
            aggregationType = transformRulesDoc.getPropVal(aggregationPath)
            unless(aggregationType == "int" or aggregationType == "float")
              errMap[aggregationPath] = "#{aggregationPath} must be \"int\" or \"float\""
            end
            unless(errMap.empty?)
              report = "Your transformation document has the following errors:\n"
              errMap.each_key{ |kk|
                vv = errMap[kk]
                report << "#{vv}\n"
              }
              raise BRL::Genboree::GenboreeError.new(:"Bad Request", report)
            end

            # retrieve kbDoc, validate it against the rules
            # @todo maybe its ok to forgo this and just error in the job helper if we have failures for this reason
            transform = BRL::Genboree::KB::Transformers::Transformer.new(transformRulesDoc)
            kbDocUrl = type2Input[:kbDoc]
            uriObj = URI.parse(kbDocUrl)
            apiCaller.setHost(uriObj.host)
            apiCaller.setRsrcPath("#{uriObj.path}?#{uriObj.query}")
            apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
            resp = apiCaller.get()
            unless(apiCaller.succeeded?)
              parsedBody = apiCaller.parseRespBody() rescue nil
              msg = (parsedBody and parsedBody['status'] and parsedBody['status']['msg']) rescue nil
              code = (parsedBody and parsedBody['status'] and parsedBody['status']['statusCode']) rescue nil
              code = (code.nil? ? :"Internal Server Error" : code.to_sym)
              raise BRL::Genboree::GenboreeError.new(code, "Could not retrieve document #{type2Input[:kbDoc]} ; Status message: #{msg.inspect}")
            end
            kbDoc = BRL::Genboree::KB::KbDoc.new(apiCaller.parseRespBody()['data'])
            valid = transform.validateTrRulesVsSrcDoc(kbDoc)
            if(valid)
              # Has this tool been submitted as public user? That's actually allowed for this tool!
              if(@userId == 0 and @hostAuthMap.empty?)
                # - If so, we have a real role-based Genboree account who can run this.
                # - But we need to fill in wbJobEntity.context stuff for this user for downstream to work.
                dbrc = BRL::DB::DBRC.new()
                dbrcRec = dbrc.getRecordByHost(@genbConf.machineName, :CLINGEN_PUB_TOOL_USER)
                if(dbrcRec)
                  wbJobEntity.context["user"] = dbrcRec[:user]
                  $stderr.debugPuts(__FILE__, __method__, "DEBUG", "Looks like public access scenario. Shimmed in CLINGEN_PUB_TOOL_USER from .dbrc to wbJobEntity.context:\n\n#{wbJobEntity.context.inspect}")
                  retVal = true
                else
                  msg = "BAD SERVER CONFIG: The Reasoner tool cannot be run in a public context because key DBRC configuration files are missing the necessary records to arrange this."
                  $stderr.debugPuts(__FILE__, __method__, "BUG", "Error:\n#{msg}\nDETAILS:\n#{transform.transformationErrors.join("\n")}")
                  wbJobEntity.context['wbErrorMsg'] = msg
                  #raise BRL::Genboree::GenboreeError.new(code, msg)
                  retVal = false
                end
              else
                retVal = true
              end
            else
              code = :"Bad Request"
              msg = "INSUFFICIENT DATA: The Reasoner cannot be run on the contents of doc: #{kbDocUrl}. It may have no Evidence on which to reason. "
              $stderr.debugPuts(__FILE__, __method__, "VALIDATION FAILURE", "Error:\n#{msg}\nDETAILS:\n#{transform.transformationErrors.join("\n")}")
              wbJobEntity.context['wbErrorMsg'] = msg
              #raise BRL::Genboree::GenboreeError.new(code, msg)
              retVal = false
            end
          end
        end
      rescue => err
        logAndPrepareError(err, wbJobEntity)
        retVal = false
      end
      return retVal
    end

    # @return [String] JSON version of model to validate rulesDoc against
    # @todo perhaps a URL pointing to a kbDoc? for now just a static model
    # @note must double escape from a plain-text version!
    def getRulesModel()
      model = <<EOS
{
  "identifier": true,
  "domain": "regexp([A-Za-z0-9]+-Guidelines)",
  "name": "GuideLines_V0_1",
  "required": true,
  "description": "For example, ACMG OR McArthurLabGuideLines",
  "properties": [
    {
      "domain": "[valueless]",
      "name": "Rules",
      "description": "Contains 1+ Rule items (rule record or rule sub-doc)",
      "items": [
        {
          "identifier": true,
          "domain": "string",
          "name": "Rule",
          "category": true,
          "required": true,
          "description": "A rule item / sub-doc / record)",
          "properties": [
            {
              "domain": "[valueless]",
              "name": "Conditions",
              "required": true,
              "description": "The list of conditions for this rule. Each rule has 1+ conditions to test.",
              "items": [
                {
                  "identifier": true,
                  "domain": "string",
                  "name": "Condition",
                  "required": true,
                  "description": "A condition item / sub-doc / record",
                  "unique": true,
                  "properties": [
                    {
                      "domain": "string",
                      "name": "PartitionPath",
                      "required": true,
                      "description": "What partition does this condition examine? Period-delimited path [of keys] in the partitioned \\"data\\" section of the partitioning transformation output."
                    },
                    {
                      "domain": "regexp(^[>,=]=\\\\d)",
                      "name": "Condition",
                      "required": true,
                      "description": "What is the conditional test applied to the value for PartitionPath? A string encoding a simple conditional test for the value in that partition"
                    },
                    {
                      "domain": "enum(sum, count, value)",
                      "name": "AggregationOperation",
                      "description": "How to aggregate multiple values when coming up with the value for PartitionPath, if ParttionPath does not point to a \\"leaf\\" or final value, but rather to a partition that has multiple values (i.e. it indicates a whole \\"column\\" which thus can have multiple values, yes?)"
                    }
                  ]
                }
              ],
              "fixed": true
            },
            {
              "domain": "string",
              "name": "Inference",
              "required": true,
              "description": "The inference if all the Conditions are met."
            }
          ],
          "unique": true
        }
      ],
      "fixed": true
    }
  ],
  "unique": true
}
EOS
      return model
    end


  end
end; end; end
