require 'brl/genboree/kb/contentGenerators/generator'
require 'brl/genboree/kb/util/autoId'

module BRL; module Genboree; module KB; module ContentGenerators
  class AutoIdTemplateGenerator < AutoIdGenerator
    include ::BRL::Genboree::KB::Util::AutoId

    # @interface
    DOMAIN_TYPE = "autoIDTemplate"

    # @override
    # For this class, generateUnique requires :template, :arguments which its parent does not
    # @param [Hash] params named parameters
    #   [Array<String>] :arguments values that should replace "%s" in the @:template@
    #   [String] :template a string containing one or more "%s" and one "%G"
    # @see generateUnique
    def validateGenerateUniqueParams(params)
      defaultValues = {
        :maxAttempts => 10,
        :scope => :collection,
        :length => 6
      }
      requiredParams = [:arguments, :propPath, :template]
      params = defaultValues.merge(params)
      missingParams = requiredParams - params.keys
      raise ArgumentError.new("Missing required parameters: #{missingParams.join(", ")}") if(!missingParams.empty?)
      return params
    end

    # @override
    # @see getIncrementIds
    def validateIncIdsParams(params)
      defaultValues = {
        :amount => 1,
        :padding => true,
        :length => 6
      }
      params = defaultValues.merge(params)
      requiredParams = [:arguments, :collName, :propPath, :template]
      missingParams = requiredParams - params.keys
      raise ArgumentError.new("Missing required parameters: #{missingParams.join(", ")}") if(!missingParams.empty?)
      return params
    end

    # @override
    # Compose an ID (that may not be unique)
    # @param [Hash] params named arguments:
    #   :arguments [Array<String>] values to fill in place of %s in @:template@
    #   :length [Integer] size of genPart to create
    #   :uniqMode [Symbol] style of ID to make
    #   :template [String] containing one %G and one or more %s to be replaced by
    #     the genPart and @:arguments@, respectively
    def composeId(params)
      requiredParams = [:arguments, :length, :uniqMode, :template]
      missingParams = requiredParams - params.keys
      raise ArgumentError.new("Missing required parameters: #{missingParams.join(", ")}") if(!missingParams.empty?)

      genPart = generateDynamic(params[:uniqMode], params[:length])
      autoId = fillTemplate(params[:template], genPart, params[:arguments])
      autoId = flagValueAsGenerated(autoId)
    end

    # @override
    # @see composeId
    # @todo combine with composeId -- only difference is in genPart
    def composeIncId(genPart, params)
      autoId = fillTemplate(params[:template], genPart, params[:arguments])
      autoId = flagValueAsGenerated(autoId)
    end
  end
end; end; end; end
