require 'brl/genboree/kb/kbDoc'
require 'brl/genboree/kb/mongoKbDatabase'
require 'brl/genboree/kb/validators/docValidator'
require 'brl/genboree/kb/helpers/transformCacheHelper'

module BRL ; module Genboree ; module KB ; module Validators
class TransformCacheValidator < DocValidator

  def initialize()
    super()
    transformCacheModel = BRL::Genboree::KB::Helpers::TransformCacheHelper::KB_MODEL
    @transformCacheModelObj = BRL::Genboree::KB::KbDoc.new(transformCacheModel)
  end

  # Validates the transformation cache document against the transformation cache model defined in the TranformCacheHelper class
  # @param [Hash] transformDoc A hash representing the view payload
  # @return [Boolean] retVal
  def validate(transformCacheDoc)
    retVal = false
    retVal = validateDoc(transformCacheDoc, @transformCacheModelObj)
    return retVal
  end
end
end ; end ; end ; end # module BRL ; module Genboree ; module KB ; module Validators
