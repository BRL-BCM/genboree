require 'brl/genboree/kb/kbDoc'
require 'brl/genboree/kb/mongoKbDatabase'
require 'brl/genboree/kb/validators/docValidator'
require 'brl/genboree/kb/helpers/queryCacheHelper'

module BRL ; module Genboree ; module KB ; module Validators
class QueryCacheValidator < DocValidator

  def initialize()
    super()
    queryCacheModel = BRL::Genboree::KB::Helpers::QueryCacheHelper::KB_MODEL
    @queryCacheModelObj = BRL::Genboree::KB::KbDoc.new(queryCacheModel)
  end

  # Validates the transformation cache document against the transformation cache model defined in the TranformCacheHelper class
  # @param [Hash] transformDoc A hash representing the view payload
  # @return [Boolean] retVal
  def validate(queryCacheDoc)
    retVal = false
    retVal = validateDoc(queryCacheDoc, @queryCacheModelObj)
    return retVal
  end
end
end ; end ; end ; end # module BRL ; module Genboree ; module KB ; module Validators
