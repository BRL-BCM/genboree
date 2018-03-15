require 'brl/genboree/kb/kbDoc'
require 'brl/genboree/kb/mongoKbDatabase'
require 'brl/genboree/kb/validators/docValidator'
require 'brl/genboree/kb/helpers/questionsHelper'
require 'brl/genboree/kb/producers/fullPathTabbedDocProducer'


module BRL ; module Genboree ; module KB ; module Validators
class QuestionValidator < DocValidator

  # domain definition with supported subset definitions
  DOMAIN_SUBSETS = {
    'int' => {'posInt' => true, 'negInt' => true, 'intRange' => true, 'numItems' => true},
    'float' => {'posFloat' => true, 'negFloat' => true, 'floatRange' => true},
    'string' => {'regexp' => true, 'enum' => true, 'url' => true, 'fileUrl' => true, 'labelUrl' => true, 'bioportalTerm' => true, 'bioportalTerms' => true, 'autoID' => true, 'pmid' => true}
  }
  # all the property paths in the questDoc
  attr_accessor :questPaths
  attr_accessor :mainTemplate
  attr_accessor :validationMessages
  # full paths. 
  attr_accessor :questFullpaths

 
  def initialize(kbDatabase, dataCollName)
    super(kbDatabase, dataCollName)
    questModel = BRL::Genboree::KB::Helpers::QuestionsHelper::KB_MODEL
    @questModelObj = BRL::Genboree::KB::KbDoc.new(questModel)
    @dh = @kbDatabase.dataCollectionHelper(@dataCollName) rescue nil
    @questPaths = {}
    @questFullpaths = {}
    @sectionRoots = {}
    @rootPath = false
    @templates = {}
  end

  # Validates the questionnaire document against the qustionnaire model defined in the QuestionsHelper class
  # @param [Hash] questDoc A hash representing the quest payload
  # @return [Boolean] retVal
  def validate(questDoc)
    @validationErrors = []
    @validationMessages = []
    sections = nil
    #1. Validate the document against the model
    docValid = false
    docValid = validateDoc(questDoc, @questModelObj)
    if(docValid == true)
      questKbDoc = BRL::Genboree::KB::KbDoc.new(questDoc)
      #2. Check against the original data collection - should be the same in the questDoc
      questCollName = questKbDoc.getPropVal('Questionnaire.Coll')
      if(@dataCollName == questCollName)
        #3a. Check the templates in each section of the questDoc. If no templates then the root should be present, pointing to the property of interest.
        sections = questKbDoc.getPropItems('Questionnaire.Sections')
        if(sections) # get the template or root from each of the sections
          modelsHelper = @kbDatabase.modelsHelper()
          modelDoc = modelsHelper.modelForCollection(@dataCollName)
          model = modelDoc.getPropVal('name.model')
          propValid = true
          domainValid = true
          isTemplateBased = false
          isDocBased = false
          sections.each{|section|
            if(@validationErrors.empty?) # Do not proceed if there are errors from the previous section
              root = nil
              questions = nil
              secKb = BRL::Genboree::KB::KbDoc.new(section) 
              secTemplate = secKb.getPropVal('SectionID.Template')
              type = secKb.getPropVal('SectionID.Type')
              docRoot = secKb.getPropVal('SectionID.Root')
              if(type == 'modifyProp')
                if(secTemplate and docRoot) # Same section has both template and doc root. BAD DOC
                  @validationErrors << "BAD_DOC: A section with the properties SectionID.Root and SectionID.Template found. These two properties are mutually exclusive."
                  break
                elsif(secTemplate)
                  isTemplateBased = true
                  if(isDocBased) # Had a section before that pointed to a document root. Both tamplate roots and document roots are mutually exclusive per questionnaire
                    @validationErrors << "BAD_DOC: A questionnaire cannot be both template based and document based at the same time. Properties 'Root' or 'Template' should be uniformly present across all the sections of your questionnaire."
                    break
                  end
                  templatesHelper = @kbDatabase.templatesHelper()
                  cursor = templatesHelper.coll.find( { "id.value" => secTemplate }  )
                  templateDoc = nil
                  # Should be just one, if matched
                  cursor.each { |dd| templateDoc = BRL::Genboree::KB::KbDoc.new(dd) }
                  if(templateDoc and !templateDoc.empty?)
                    @templates[secTemplate] = templateDoc
                    templateDoc.delete("_id")
                    tempCollName = templateDoc.getPropVal('id.coll')
                    #3b. Check whether the coll in the template is in sync with the questCollName
                    if(tempCollName == questCollName)
                      root = templateDoc.getPropVal('id.root')
                      if(root.strip.empty?) # templates support empty string root which is actual document identifier
                        root = @dh.getIdentifierName()
                      end
                      @sectionRoots[root] = secTemplate 
                    else
                      @validationErrors << "BAD_DOC: Template collection - #{tempCollName} failed to match the Questionnaire collection - #{questCollName}"
                      break
                    end
                  else
                    @validationErrors << "NO_TEMPLATE: There is no template: #{secTemplate} for the database #{@kbDatabase.name}"
                    break
                  end            
                elsif(docRoot)
                  isDocBased = true
                  if(isTemplateBased) # Had a section before that pointed to a template root. Both tamplate roots and document roots are mutually exclusive per questionnaire 
                    @validationErrors << "BAD_DOC: A questionnaire cannot be both template based and document based at the same time. Properties 'Root' or 'Template' should be uniformly present across all the sections of your questionnaire."
                    break
                  end 
                  root = docRoot
                  @sectionRoots[root] = true
                  # To be supported in the next version
                  @validationErrors << "NOT_SUPPORTED: There is no template, but a root #{docRoot}. Use of questionnaire with a Genboree KB document is not currently supported"
                  break
                else
                  @validationErrors << "BAD_DOC: Both template and root property misssing from the section - #{secKb.getPropVal('SectionID.Template')} in the Questionnaire. At least one of the properties must be present."
                  break
                end

             else
               @validationErrors << "BAD_DOC: Type #{type} is not currently supported and hence is not a valid document for this version of questionnaires. Supported task is - modifyProp"
               break
             end


              # Have root info at this point. Validate all the property paths and the respective domains
              questions = secKb.getPropItems('SectionID.Questions')
              if(questions and propValid and domainValid)
                questions.each{|quest|
                  questKb = BRL::Genboree::KB::KbDoc.new(quest)
                  questPropPath = questKb.getPropVal('QuestionID.Question.PropPath')
                  #4. Property paths in the questDoc are valid (check against the model of the collection mentioned in the questDoc)
                  propValid = validatePropPath(root, questPropPath, modelsHelper)
                  if(propValid)
                    #5. Check the domain
                    questPropDomain = questKb.getPropVal('QuestionID.Question.PropPath.Domain')
                    domainValid = validatePropDomain(root, questPropPath, modelsHelper, model, questPropDomain.strip())
                    break unless(domainValid)      
                  else
                    break
                  end
                }
              end
            end
          } 
        end
      else
        @validationErrors << "BAD_DOC: CollName in the Questionnaire document #{questKbDoc.getPropVal('Questionnaire')} failed to match the user collname #{@dataCollName}. Check spelling, cases, etc."
      end
    end
    validateReqdProps() if(@validationErrors.empty?)
    if(@validationErrors.empty?)
      unless(@rootPath)
        @validationErrors << "BAD_DOC: No questions with property path for the document identifier is found. This question document is hence invalid."
      end
    end
    validateTemplates() if(@validationErrors.empty?)
    retVal = @validationErrors.empty? ? true : false 
    return retVal 
  end
  
  # concatenates the root property path and the property path of a question
  # and validates the full path against the model
  # @param [String] rootProp root of the template or the root to which the section
  #   of the questionnaire points to
  # @param [Sting] propPath property path of a specific question
  # @param [Object] modelsHelper instance of class BRL::Genboree::KB::Helpers::ModelsHelper
  # @return [Boolean] isValid true when the path is valid
  def validatePropPath(rootProp, propPath, modelsHelper)
    isValid = false
    docPath = nil
    begin
      path = propPath.gsub(/(\.(\[.*?\]))/, "")
      fullPath = (path.strip().empty?) ? "#{rootProp.strip()}": "#{rootProp.strip()}.#{path.strip()}"
      docPath = modelsHelper.modelPath2DocPath(fullPath, @dataCollName)
      @questPaths[propPath] = fullPath
      if(@questFullpaths.key?(fullPath))
        # This path already seen!
        isValid = false
        @validationErrors << "BAD_DOC: #{propPath} is being used more than once for this questionnaire document. This is not allowed as a question cannot be asked for the same property again. It should rather be unique."
        return isValid
      else
        @questFullpaths[fullPath] = true
      end
      @rootPath = true if(fullPath == @dh.getIdentifierName()) # proppath to the doc Identifier
      isValid = (docPath.nil? ? false : true)
    rescue => err
      @validationErrors << "BAD_DOC : Invalid propPath - #{propPath} - Details: #{err.message}"
    end
    return isValid
  end

  # validates the domain definition and subset domain definitions for a given property path
  # @param [String] rootProp root property to which the template or the section of the
  #   questionnaire points to
  # @param [String] propPath property path of a specific question
  # @param [Object] modelsHelper instance of class BRL::Genboree::KB::Helpers::ModelsHelper
  # @param [BRL::Genboree::KB::KbDoc] model a full model definition
  # @param [String] questDomain domain definiton of the property path from the questionnaire
  # @return [Boolean] IsValid true when the domain definition is valid
  def validatePropDomain(rootProp, propPath, modelsHelper, model, questDomain)
    isValid = false
    propDef = nil
    path = propPath.gsub(/(\.(\[.*?\]))/, "")
    fullPath = (path.strip().empty? or (rootProp == propPath)) ? "#{rootProp.strip()}": "#{rootProp.strip()}.#{path.strip()}"
    propDef = modelsHelper.findPropDef(fullPath, model)
    domain = propDef ? (propDef['domain'] or 'string') : 'string'
  
    # If the domain of the propPath is valueless
    if(domain !~ /^\[valueless\]$/)
   
      # validate questDomain with domain from the original model
      if(DOMAIN_SUBSETS.key?(domain.to_s))
        questDomain =~ /^(.+?)(\((.*)\))*$/
        if(DOMAIN_SUBSETS[domain.to_s].key?($1) or (domain.to_s == $1))
          isValid = true
        else
          @validationErrors << "BAD_DOC: Domain #{questDomain.inspect} in the Questionnaire failed to match the original model domain definition #{domain} for the property #{propPath}. Most probably the domain definition #{questDomain.inspect} is inavlid, check the spelling, case, etc. Or this particular subset domain definition is not currenlty supported."
        end
      # handle enum separately
      elsif(domain =~ /^enum\(\s*(\S.*)\)$/)
          enumHash = {}
          $1.gsub(/\\,/, "\v").split(/,/).each { |yy| enumHash[yy.gsub(/\v/, ',').strip] = true }

          if(questDomain =~ /^enum\(\s*(\S.*)\)$/)
            questDoms = []
            isValid = true
            $1.gsub(/\\,/, "\v").split(/,/).each { |yy|
              if(!enumHash.key?(yy.gsub(/\v/, ',').strip))
                isValid = false
                @validationErrors << "BAD_DOC: Domain #{questDomain.inspect} in the Questionnaire failed to match the original model domain definition #{domain} for the property #{propPath}. Most probably the domain definition #{questDomain.inspect} is inavlid, check the spelling, case, etc."
                break
              end
             }
          else
            @validationErrors << "BAD_DOC: Domain #{questDomain.inspect} in the Questionnaire failed to match the original model domain definition #{domain} for the property #{propPath}. Most probably the domain definition #{questDomain.inspect} is inavlid, check the spelling, case, etc."
          end
      #must be exact match
      else
        if(domain.to_s == questDomain.strip().to_s)
          isValid = true
        else
          @validationErrors << "BAD_DOC: Domain #{questDomain.inspect} in the Questionnaire failed to match the original model domain definition #{domain} for the property #{propPath}. Most probably the domain definition #{questDomain.inspect} is inavlid, check the spelling, case, etc. Or this particular subset domain definition is not currenlty supported." 
        end 
      end
    else
      isValid = false
      @validationErrors << "BAD_DOC: Domain for the property path as per the model is #{domain.inspect}, for the property path for the property #{propPath}. Asking questions for a valueless property is not allowed. "
    end
    return isValid
  end

  # Validate whether the questionnaire can generate a valid document.
  def validateReqdProps()
    @mainTemplate = {:root => nil, :template => nil}
    hasAllReqdProps = true
    # If the questionnaire is supported by a template, then all the sections are to be supported by templates
    # Cannot have a template based and document based questionnaire at the same time.
    # Validate whether the questionnaire can generate a valid document.
    # Current version supports only the use of templates. So most of the validation is already done there
    # Check whether roots of templates (from different sections). If there is no root pointing
    # to the document identifier then reject the questionnaire
    identifier = @dh.getIdentifierName()
    # This should be good for the first version where only template-based questionnaires are supported
    # Need additional validation if the questionnaire is not template-based - DEFERRED
    if(@sectionRoots.key?(identifier)) # If none of the roots points to identifer
      @mainTemplate[:root] = identifier
      @mainTemplate[:template] = @sectionRoots[identifier]
    else
      hasAllReqdProps = false
      @validationErrors << "BAD_DOC: This questionnaire is not prepared to generate a valid document for the collection #{@kbDatabase}. Identifier property of the document -  #{identifier} is missing which should be acknowledged either through a proper template or a valid document."
    end
    return hasAllReqdProps
  end
 
  # template specific validations 
  def validateTemplates()
    templateValid = true
    # Check if a static property (a property not covered by a question) appears more than once in templates
    #
    modelsHelper = @kbDatabase.modelsHelper()
    modelDoc = modelsHelper.modelForCollection(@dataCollName)
    model = modelDoc.getPropVal('name.model')
    tb = BRL::Genboree::KB::Producers::FullPathTabbedDocProducer.new(model)
    # hash to keep track of unique property paths
    props = {}

    # get each template.
    @templates.each_key {|tem|
      if(templateValid)
        doc = {}
        temp = @templates[tem]
        tempRoot = temp['id']['properties']['root']['value']
        tempRoot = @dh.getIdentifierName() if(tempRoot.strip.empty?)
        doc[tempRoot] = temp['id']['properties']['template']['value']
        fullpaths = tb.produce(doc)
        fullpaths.shift
        fullpaths.each{|line| 
          path = line.split("\t")[0]
          path = path.gsub(/(\.(\[.*?\]))/, "")
          #@questFullpaths
          if(props.key?(path))
              # check if covered by a question already
              unless(@questFullpaths.key?(path))
                templateValid = false
                @validationErrors << "BAD_TEMPLATES: Template property #{path} appearing more than once and not covered by a question. This is not allowed. A static property in a template cannot exist more than once among templates. Check the template #{tem} and other templates in the questionnaire."
                break
              end
          else
            # new path, add to the unique hash
            props[path] = true
          end
        }
      end
    }
    return templateValid
  end

end
end ; end ; end ; end # module BRL ; module Genboree ; module KB ; module Validators
