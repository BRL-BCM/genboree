require 'time'
require 'date'
require 'uri'
require 'sha1'
require 'json'
require 'brl/util/util'
require 'brl/extensions/units'
require 'brl/genboree/kb/kbDoc'
require 'brl/genboree/kb/mongoKbDatabase'
require 'brl/genboree/kb/validators/docValidator'
require 'brl/genboree/kb/helpers/transformsHelper'

module BRL ; module Genboree ; module KB ; module Validators
class TransformValidator < DocValidator

  def initialize()
    super()
    transformModel = BRL::Genboree::KB::Helpers::TransformsHelper::KB_MODEL
    @transformModelObj = BRL::Genboree::KB::KbDoc.new(transformModel)
  end

  # Validates the transformation document against the transformation model defined in the TranformsHelper class
  # @param [Hash] transformDoc A hash representing the view payload
  # @return [Boolean] retVal
  def validate(transformDoc)
    retVal = false
    retVal = validateDoc(transformDoc, @transformModelObj)
    return retVal
  end
end
end ; end ; end ; end # module BRL ; module Genboree ; module KB ; module Validators
