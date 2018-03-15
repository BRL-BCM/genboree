require 'brl/genboree/kb/propSelector'
require 'brl/genboree/kb/validators/queryValidator'
require 'brl/genboree/kb/validators/modelValidator'
require 'brl/genboree/kb/helpers/queriesHelper'
require 'brl/genboree/kb/helpers/viewsHelper'

module BRL ; module Genboree ; module KB ; module Queries

  # Class for using a Genboree KB query document to query a KB collection
  # This class is instantiated with a Hash which is
  # a valid query document whose structure is dictated by the
  # model given in queriesHelper and the model resides in kbQueries internal collection

  class AbstractQueries
     
    # The query document
    attr_accessor :queryDoc
    
    # Errors encountered are entered here
    attr_accessor :queryErrors
    
    attr_accessor :queryStatus
    
    # complete query configuration, are elements of an item list
    attr_accessor :queryConfig
    
    # query type is either matchQuery or projectQuery.
    # projectQuery - when the configuration has comparison for property fields
    # at both left and right operands. Mongo DB supports this only in an aggregation
    # framework and also in a project stage.
    # For all the other cases it is a matchQuery
    attr_accessor :queryType
    
    # All the property paths (all KbDoc paths) present in the query configuration
    attr_accessor :propPaths
    
    # query string generated from the configuration
    attr_accessor :query
    
    # queried documents count available through method queryColl and option {:count}
    attr_accessor :queriedDocCount
  
  
    LOGICAL_OPERATORS = {:and => "$and", :or => "$or"}
    COMPARATIVE_OPERATORS = {:'=' => "$eq", :'!=' => "$ne", :'>' => "$gt", :'<' => "$lt", :'>=' => "$gte", :'<=' => "$lte", :in => "$in", :exact => "$eq", :prefix => "$regex", :full => "$regex", :keyword => "$regex"}
  
    # CONSTRUCTOR
    # @param [Hash] queryDoc the query document
    # @param [Object] mongoKbDb a BRL::Genboree::KB::MongoKbDatabase instance
    # @raise [ArgumentError] if @queryDoc@ is not a valid query document
    def initialize(queryDoc, mongoKbDb)
      @queryDoc = queryDoc
      @mongoKbDb = mongoKbDb
      @mv = BRL::Genboree::KB::Validators::ModelValidator.new()
      preValidationPassed = preValidate()
      raise ArgumentError, "QUERY_DOC_ERROR: Prevalidation step failed.\n #{@queryErrors.join("\n")}" unless(preValidationPassed)
    end 
  
    # Validates the configuration and extracts all the query information
    # @return [boolean] queryStatus true if the document is valid
    def preValidate()
      @queryErrors = Array.new()
      @queryStatus = true
      @queryConfig = {}
      @propPaths = {}
      @query = nil
      @queriedDocCount = nil
      @queryType = 'matchQuery'
      @kbDocument = BRL::Genboree::KB::KbDoc.new(@queryDoc)
      @propSel = BRL::Genboree::KB::PropSelector.new(@queryDoc)
      @operandTypes = {:propPath => 'propPath', :literal => 'literal', :'Query Config' => 'Query Config'}
      # options for aggregation, input argument for the method queryColl()
      @aggOpts = Hash.new()
      
      # 1. Validate against the model
      queryValidator = BRL::Genboree::KB::Validators::QueryValidator.new()
      @queryStatus = queryValidator.validate(@queryDoc)
      if(@queryStatus)
        #  2. Check if the prop path values are not empty
        queryItems = @propSel.getMultiPropItems("<>.Query Configurations") rescue nil
        if(queryItems and !queryItems.empty?)
          # Get the first query config Id . Used for trigerring the recursion
          @firstQCId = queryItems[0]['Query Config']['value']
          #  a. get the query config wrp to the query config id into a hash 
          @queryConfig = queryItems.inject({}){|hh, kk| hh[kk['Query Config']['value']] = kk; hh;}        
          # get the property paths
          # Check that QC-QC or propPath-propPath or propPath-literal
          # Look up is cheaper than using kbDoc or propSel, required properties are not rescued
          queryItems.each{|qitem|
            leftOpType = qitem['Query Config']['properties']['Left Operand']['value']
            rightOpType = qitem['Query Config']['properties']['Right Operand']['value']
            leftOpQC = qitem['Query Config']['properties']['Left Operand']['properties']['Query Config ID']['value'] rescue nil
            rightOpQC = qitem['Query Config']['properties']['Right Operand']['properties']['Query Config ID']['value'] rescue nil
            leftOpValue = qitem['Query Config']['properties']['Left Operand']['properties']['Value']['value'] rescue nil
            rightOpValue = qitem['Query Config']['properties']['Right Operand']['properties']['Value']['value'] rescue nil
            operator = qitem['Query Config']['properties']['Operator']['value'].to_sym
            if(leftOpType == @operandTypes[:propPath] and (rightOpType == @operandTypes[:propPath] or rightOpType == @operandTypes[:literal]))
              # Check if the values are present
              if(leftOpValue and rightOpValue and leftOpValue =~ /\S/ and rightOpValue =~ /\S/)
                leftOpValue = leftOpValue.gsub(/(.\[.*\])/, "")
                @propPaths[leftOpValue] = nil
                # Check the operator. should be   
                if(!COMPARATIVE_OPERATORS.key?(operator))
                  @queryStatus = false
                  @queryErrors << "INVALID_OPERATOR: The operator #{operator.inspect} MUST be a comparative operator as both the left operand and right operand are of the type #{leftOpType} and #{rightOpType} respectively. Logical operators: #{LOGICAL_OPERATORS.keys.inspect} are allowed only when both the operands are of the type 'Query Config'" 
                  break
                elsif(rightOpType == @operandTypes[:propPath])
                  rightOpValue = rightOpValue.gsub(/(.\[.*\])/, "")
                  @propPaths[rightOpValue] = nil
                  if(operator == :keyword or operator == :full or operator == :prefix)
                    @queryStatus = false
                    @queryErrors << "INVALID_QUERY: The operator #{operator.inspect} is mutually exclusive when the left and right operands are of the types - #{leftOpType} and #{rightOpType}"
                    break
                  else
                    @queryType = (@queryType == 'matchQuery') ? 'projectQuery' : @queryType
                  end
                end
              else
                @queryStatus = false
                @queryErrors << "INVALID_OPERAND_VALUE: Left Operand #{leftOpValue.inspect} or right operand #{rightOpValue.inspect} or both are missing for the operand types - #{leftOpType.inspect} and #{rightOpType.inspect} respectively."
                break 
              end
            elsif(leftOpType == @operandTypes[:'Query Config'] and rightOpType == @operandTypes[:'Query Config'])
              if(leftOpQC and rightOpQC and (leftOpQC != rightOpQC))
                unless(LOGICAL_OPERATORS.key?(operator))
                  @queryStatus = false
                  @queryErrors << "INVALID_OPERATOR: The operator #{operator.inspect} MUST be a logical operator as both the left operand and right operand are of the type #{leftOpType} and #{rightOpType} respectively."
                  break
                end
              else
                @queryStatus = false
                @queryErrors << "INVALID_OPERAND_QC_VALUE: Left Operand #{leftOpQC.inspect} or right operand #{rightOpQC.inspect} or both are missing or CANNOT be equal for the operand types - #{leftOpType.inspect} and #{rightOpType.inspect} respectively."
                break
              end
            else
              @queryStatus = false
              @queryErrors << "INVALID_OPERAND_TYPES: The left - #{leftOpType} and right - #{rightOpType} operand types are invalid together."
              break
            end
          }
        else
          @queryStatus = false
          @queryErrors << "INVALID_DOC: The input document must contain at least one query configuration item. The path '<>.Query Configurations' is either empty or invalid."
        end
      else
        # Ensure this is Array<String> even if newer hash-of-errors-keyed-by-propPath is available
        if( queryValidator.respond_to?(:buildErrorMsgs) )
          validatorErrors = queryValidator.buildErrorMsgs
        else
          validatorErrors = queryValidator.validationErrors
        end
        @queryStatus = false

        @queryErrors << "INVALID_DOC: The input document failed vaildation against the query model. #{validatorErrors.join("\n")}"
      end
      return @queryStatus
    end
    
    # queries a collection
    # @param [String] collName name of the collection
    # @param [Hash] aggOpts options for the aggreagtion
    #  Options include:
    #  {:docIdOnly => true} option to add a project stage to get just the document ids
    #  {:view => viewName} option to add the property paths from a view to the project stage
    #  {:count => true} option to get the count of the queried documents, done by
    #    adding a group config/stage to the aggregation. Two aggregation mehtods are called
    #    if this option is enabled. Count available from the instance variable @queriedDocCount
    # @param [boolean] returnCursor this asks for a cursor from the aggregation rather than a list.
    def queryColl(collName, aggOpts={}, returnCursor=true)
      result = nil
      aggPipeline = []
      options = {}
      @aggOpts = aggOpts
      # Get the agg pipeline for the queryDoc
      aggPipeline = createAggPipeline(collName)
      options = {:cursor => {}} if(returnCursor)
      if(@queryStatus and !aggPipeline.empty?)
        result = aggregateColl(collName, aggPipeline, options)
      end
    end

    # aggregates the collection using the aggregation pipelines and other
    # mongo allowed options (cursor)
    # @param [String] collName name of the collection
    # @param [Array<Hash>] list of aggregation stages
    # @param [Hash] options these are the options allowed by mongo
    # used here are {:cursor => {}}
    def aggregateColl(collName, aggPipeline, options={})
      res = nil
      dataHelper = @mongoKbDb.dataCollectionHelper(collName.strip) rescue nil
      if(dataHelper) #TO DO MOST IMP!!!!!!!!!!!! MongoError
        # rescue the error, mongo specific error look up!!!!!!!!
        res = dataHelper.coll.aggregate(aggPipeline, options)
        #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "RESULT: #{res.inspect}")
      end      
      return res
    end
    
    # build the query
    # @param [String] collName
    # @return [Hash] @query query generated
    # @note error rescued while validating the property paths by expanding them
    def buildQuery(collName)
      @query = nil
      dataHelper = @mongoKbDb.dataCollectionHelper(collName.strip) rescue nil
      unless(dataHelper)
        @queryStatus = false
        @queryErrors << "NO_COLL: No data collection #{collName.inspect} in the GenboreeKB - #{@mongoKbDb.name}, (check spelling/case, etc)."
      else
        begin
          modelsHelper = @mongoKbDb.modelsHelper()
          # Get the model for the collection
          modelDoc = modelsHelper.modelForCollection(collName)
          model = modelDoc.getPropVal('name.model')
          # First add the identifier prop to the @propPaths
          idPropName = dataHelper.getIdentifierName()
          @propPaths[idPropName] = nil
          # @propPaths has other property paths from the query docs already
          # validate all the prop paths in the query Doc against the model by expanding all at once
          # The key value is updated with the expanded path
          validatePropPaths(@propPaths, modelsHelper, collName)
          @query = (@queryType == 'matchQuery') ? buildMatchQuery(modelsHelper, model, collName, @queryConfig, @firstQCId) : buildProjectQuery(modelsHelper, model, collName, @queryConfig, @firstQCId)
        rescue => err
          @query = nil
          @queryStatus = false
          @queryErrors << "QUERY_BUILD_ERROR: #{err.message}"
        end
      end
      return @query
    end
    
    
    # recursion to build a match query
    # @param [Object] modelsHelper instance of class BRL::Genboree::KB::Helpers::ModelsHelper
    # @param [Hash] model model document of the collection @collName@
    # @param [String] collName name of the collection
    # @param [Array <Hash>] queryConfg list of query configuration
    # @param [String] qId query configuration id of the first configuration
    # @param [Hash] query the query hash that is build in each recursion
    def buildMatchQuery(modelsHelper, model, collName, queryConfg, qId, query={})
      
      leftOpType = queryConfg[qId]['Query Config']['properties']['Left Operand']['value'] rescue nil
       
      if(leftOpType == @operandTypes[:propPath])
        leftOpVal = queryConfg[qId]['Query Config']['properties']['Left Operand']['properties']['Value']['value'] rescue nil
        leftOpVal = leftOpVal.gsub(/(.\[.*\])/, "") if(leftOpVal)
        rightOpVal = queryConfg[qId]['Query Config']['properties']['Right Operand']['properties']['Value']['value'] rescue nil
        operator = queryConfg[qId]['Query Config']['properties']['Operator']['value'] rescue nil
        leftOpPath = @propPaths[leftOpVal]      
        propDef = modelsHelper.findPropDef(leftOpVal, model)
        
        # modify the val type by matching the value to the property domain and/or operator
        rightOpModVal = matchValType(leftOpVal, rightOpVal, propDef, operator.to_sym)
        
        # Once the validation is done make the query
        query[leftOpPath] = {}
        query[leftOpPath][COMPARATIVE_OPERATORS[operator.to_sym]] = rightOpModVal
      else
        operator = queryConfg[qId]['Query Config']['properties']['Operator']['value'] rescue nil
        operator = LOGICAL_OPERATORS[operator.to_sym]
        leftOpQC = queryConfg[qId]['Query Config']['properties']['Left Operand']['properties']['Query Config ID']['value'] rescue nil
        rightOpQC = queryConfg[qId]['Query Config']['properties']['Right Operand']['properties']['Query Config ID']['value'] rescue nil

        query[operator] = []
        query[operator][0] = {}
        query[operator][1] = {}

        buildMatchQuery(modelsHelper, model, collName, queryConfg, leftOpQC, query[operator][0])
        buildMatchQuery(modelsHelper, model, collName, queryConfg, rightOpQC, query[operator][1])
      end
      return query
    end

    # recursion to build a project
    # @param [Object] modelsHelper instance of class BRL::Genboree::KB::Helpers::ModelsHelper
    # @param [Hash] model model document of the collection @collName@
    # @param [String] collName name of the collection
    # @param [Array <Hash>] queryConfg list of query configuration
    # @param [String] qId query configuration id of the first configuration
    # @param [Hash] query the query hash that is build in each recursion
    def buildProjectQuery(modelsHelper, model, collName, queryConfg, qId, query={})
      leftOpType = queryConfg[qId]['Query Config']['properties']['Left Operand']['value'] rescue nil
      if(leftOpType == @operandTypes[:propPath])
        leftOpVal = queryConfg[qId]['Query Config']['properties']['Left Operand']['properties']['Value']['value'] rescue nil
        leftOpVal = leftOpVal.gsub(/(.\[.*\])/, "") if(leftOpVal)
        rightOpVal = queryConfg[qId]['Query Config']['properties']['Right Operand']['properties']['Value']['value'] rescue nil
        rightOpType = queryConfg[qId]['Query Config']['properties']['Right Operand']['value'] rescue nil
        operator = queryConfg[qId]['Query Config']['properties']['Operator']['value'] rescue nil
        if(rightOpType == @operandTypes[:propPath])
          # check if both the domain definitions match
          leftOpPath = @propPaths[leftOpVal]
          rightOpVal = rightOpVal.gsub(/(.\[.*\])/, "") if(rightOpVal)
          rightOpPath = @propPaths[rightOpVal]
          propDefs = [leftOpVal, rightOpVal].map {|path| modelsHelper.findPropDef(path, model)}
          rightOperand = "$#{rightOpPath}"   
        else # is a literal
          leftOpPath = @propPaths[leftOpVal]
          propDef = modelsHelper.findPropDef(leftOpVal, model)
          rightOperand = matchValType(leftOpVal, rightOpVal, propDef, operator.to_sym)
        end
        query[COMPARATIVE_OPERATORS[operator.to_sym]] = []
        query[COMPARATIVE_OPERATORS[operator.to_sym]] << "$#{leftOpPath}"
        query[COMPARATIVE_OPERATORS[operator.to_sym]] << rightOperand
      else# QC-QC
        operator = queryConfg[qId]['Query Config']['properties']['Operator']['value']
        operator = LOGICAL_OPERATORS[operator.to_sym]
        leftOpQC = queryConfg[qId]['Query Config']['properties']['Left Operand']['properties']['Query Config ID']['value'] rescue nil
        rightOpQC = queryConfg[qId]['Query Config']['properties']['Right Operand']['properties']['Query Config ID']['value'] rescue nil
        query[operator] = []
        query[operator][0] = {}
        query[operator][1] = {}
        buildProjectQuery(modelsHelper, model, collName, queryConfg, leftOpQC, query[operator][0])
        buildProjectQuery(modelsHelper, model, collName, queryConfg, rightOpQC, query[operator][1])
      end
      #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "FINAL QUERY : :::::::::#{query.inspect}")
      return query
    end
     
    # gets the value modified based on the domain and operator
    # @param [String] propVal
    # @param [String] domain
    # @param [Symbol] operator
    def matchValType(propPath, propVal, propDef, operator=nil)
      modVal = nil
      pathElems = propPath.split('.')
      validInfo = {}
      validInfo = @mv.validVsDomain(propVal, propDef, pathElems, {:castValue => true})
      unless(validInfo[:result] == "INVALID")
        modVal = validInfo[:castValue]
      else
        raise "ERROR, The value #{propVal} for the property #{propPath} is invalid. Failed to get the casted value."
      end
      if(operator == :full)
        modVal = /^#{modVal}$/i
      elsif(operator == :keyword)
        modVal = /#{modVal}/i
      elsif(operator == :prefix)
        modVal = /^#{modVal}/i
      end
      return modVal
    end

    # creates aggregation pipeline
    # @param [String] collName name of the collection that is to be queried
    # @return [Array<Hash>] aggPipeline list of aggregation stages - project, match and/or group 
    def createAggPipeline(collName)
      aggPipeline = nil
      projectCon = nil
      matchConf = nil
      finalProj = nil
      
      # 1. Generate the query. Validation of the collection against the mdb is done elsewhere(buildQuery)
      @query = buildQuery(collName)
      # 2. Build the configuration stages of the aggregation pipeline
      if(@queryStatus)
        begin
          aggPipeline = []
          projectSpecs = {}
          projectSpecs[:field] = {}
          viewPropHash = {}
          # See if any special property paths being requested, via views
          # If yes add those paths to the propPaths
          if(@aggOpts[:view])
            viewProps =  getViewProps()
            viewPropHash = viewProps.inject({}) {|hh, kk| hh[kk] = nil; hh}
            validatePropPaths(viewPropHash, @mongoKbDb.modelsHelper, collName)
            @propPaths = @propPaths.merge(viewPropHash)
          end
          # Get the property path in the matchOrderBy
          # These paths are to be merged with the rest of the property paths
          if(@aggOpts[:matchOrderBy])
            matchOrderHash = @aggOpts[:matchOrderBy].inject({}) {|hh, kk| hh[kk] = nil; hh}
            validatePropPaths(matchOrderHash, @mongoKbDb.modelsHelper, collName)
            @propPaths = @propPaths.merge(matchOrderHash)
          end
          @propPaths.each_key {|path| 
            value = @propPaths[path]
            projectSpecs[:field][value] = 1 
          } 
          # Pass only the required paths through the project stage
          projectCon = makeProjectCnfg({}, projectSpecs)
          if(@queryType == 'matchQuery')
            # 1. First get the prjection config with all the property paths
            aggPipeline << projectCon
            # 2. make the match config
            matchConf = makeMatchCnfg({}, @query)
            aggPipeline << matchConf
          else
            # 1. First projection query has both the property paths and query in a single projection
            projectCon = makeProjectCnfg(projectCon, {:field => {'eq' => @query}})
            aggPipeline << projectCon
            matchConf = makeMatchCnfg({}, {'eq' => true})
            aggPipeline << matchConf
          end
          # filter the records to have only the document ids
          if(@aggOpts[:docIdOnly])
            dataHelper = @mongoKbDb.dataCollectionHelper(collName.strip) rescue nil
            if(dataHelper) 
              idPropName = dataHelper.getIdentifierName()
              projectSpecs[:field] = {}
              projectSpecs[:field][@propPaths[idPropName]] = 1
              finalProj =  makeProjectCnfg({}, projectSpecs)
              aggPipeline << finalProj
            end
          elsif(@aggOpts[:view])
            dataHelper = @mongoKbDb.dataCollectionHelper(collName.strip) rescue nil
            idPropName = dataHelper.getIdentifierName()
            projectSpecs[:field] = {}
            projectSpecs[:field][@propPaths[idPropName]] = 1
            viewPropHash.each_key{|viewProp|
              value = viewPropHash[viewProp]
              projectSpecs[:field][value] = 1 
            }
            finalProj =  makeProjectCnfg({}, projectSpecs)
            aggPipeline << finalProj
          end
          # Make the sort config 
          if(@aggOpts[:matchOrderBy])
            sortCnfg = makeSortCnfg(@aggOpts[:matchOrderBy])
            aggPipeline << sortCnfg
          end
        rescue => err
          @queryStatus = false
          @queryErrors << "AGG_PIPELINE: Failed to build the aggregation pipeline for the query type : #{@queryType.inspect}. #{err.message}"
          aggPipeline = nil
        end      
      end
      #$stderr.debugPuts(__FILE__, __method__, "DEBUG", " AGGPIPELINE: #{aggPipeline.inspect}")
      return aggPipeline
    end

    # gets the count of the queried documents by performing an aggregation
    # @param [collName] collName name of the collection that is being queried
    # @return [Integer] queriedDocCount count of the queried coument retrieved from the cursor
    def getQueriedDocCount(collName)
      groupConfg = nil
      countDoc = {}
      countPipeline = []
      countPipeline = createAggPipeline(collName)
      groupConfg = makeGroupCnfg(collName)
      $stderr.debugPuts(__FILE__, __method__, "DEBUG", " GROUP: #{groupConfg.inspect}")
      countPipeline << groupConfg
      $stderr.debugPuts(__FILE__, __method__, "DEBUG", " COUNT-AGG: #{countPipeline.inspect}")
      if(@queryStatus and !countPipeline.empty?)
        begin
        result = aggregateColl(collName, countPipeline, {:cursor => {}})
        if(result and result.is_a?(Mongo::Cursor))
          countDoc = BRL::Genboree::KB::KbDoc.new(result.next)
          if(countDoc.empty?)
            @queriedDocCount = 0
          else
            @queriedDocCount = countDoc['count']
          end
        else
          @queryStatus = false
          @queryErrors = "GROUP_CONFIG_ERROR: Error in aggregation with group config."
        end
        rescue => err
          @queryStatus = false
          @queryErrors = "GROUP_CONFIG_ERROR: Error in aggregation with group config. #{err.message}"
        end
      end
      return @queriedDocCount
    end

##########################HELPER METHODS##############################

    # expands the property paths using the modelHelper
    # raised error from this method modelPath2DocPath is rescued elsewhere
    def validatePropPaths(propPathsHash, modelsHelper, collName)
      # strip any item list representations
      propPathsHash.each_key {|path|
      propPathsHash[path] = modelsHelper.modelPath2DocPath(path, collName)
    }
    end
    
    
    def makeProjectCnfg(project={}, specs={})
      (project = {} and project['$project'] = {}) unless(project.key?('$project'))
      if(specs.key?(:id))
        idValue = (specs[:id].to_s =~ /^(0|1|true|false)$/) ? specs[:id] : 0
        project['$project']['_id'] = idValue
      else #supress
        project['$project']['_id'] = 0
      end
      if(specs.key?(:field))
        specs[:field].each_key {|field|
          project['$project'][field] = specs[:field][field]
        }
      end
      return project
    end

    def makeMatchCnfg(match, query={})
      (match = {} and match['$match'] = {}) unless(match.key?('$match'))
      match['$match'] = query
      return match 
    end
 

    def makeGroupCnfg(collName, group={}, specs={})
      (group = {} and group['$group'] = {}) unless(group.key?('$group'))
      if(specs.key?(:id))
        group['$group']['_id'] = specs[:id]
      else
        group['$group']['_id'] = nil
      end
      group['$group']['count'] = {'$sum' => 1}
      return group
    end
  
    def makeSortCnfg(props)
      sortConfg = {'$sort' => {}}
      props.each {|prop| sortConfg['$sort'][prop] = 1 }
      return sortConfg
    end 
    
    def getViewProps()
      viewProps = []
      viewName = @aggOpts[:view]
      if(!BRL::Genboree::KB::Helpers::ViewsHelper::IMPLICIT_VIEWS_DEFS.key?(viewName))
        viewsHelper = @mongoKbDb.viewsHelper()
        viewCursor = viewsHelper.coll.find({ "name.value" => viewName})
        if(viewCursor and viewCursor.is_a?(Mongo::Cursor) and viewCursor.count > 0)
          viewCursor.rewind!
          doc = BRL::Genboree::KB::KbDoc.new( viewCursor.first )
          viewPropsList = doc['name']['properties']['viewProps']['items']
          viewPropsList.each {|propObj| viewProps << propObj['prop']['value']}
        end
      end
      return viewProps
    end
  
  

  end
end ; end ; end ;  end
