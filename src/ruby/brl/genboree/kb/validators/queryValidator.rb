require 'brl/genboree/kb/kbDoc'
require 'brl/genboree/kb/mongoKbDatabase'
require 'brl/genboree/kb/validators/docValidator'
require 'brl/genboree/kb/helpers/queriesHelper'

module BRL ; module Genboree ; module KB ; module Validators
class QueryValidator < DocValidator

  def initialize()
    super()
    queryModel = BRL::Genboree::KB::Helpers::QueriesHelper::KB_MODEL
    @queryModelObj = BRL::Genboree::KB::KbDoc.new(queryModel)
  end

  # Validates the query document against the query model defined in the QueriesHelper class
  # @param [Hash] queryDoc A hash representing the view payload
  # @return [Boolean] retVal
  def validate(queryDoc)
    retVal = false
    retVal = validateDoc(queryDoc, @queryModelObj)
    return retVal
  end
end
end ; end ; end ; end # module BRL ; module Genboree ; module KB ; module Validators
