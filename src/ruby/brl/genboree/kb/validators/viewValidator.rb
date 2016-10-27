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
require 'brl/genboree/kb/helpers/viewsHelper'

module BRL ; module Genboree ; module KB ; module Validators
  class ViewValidator < DocValidator

  def initialize()
    super()
    viewModel = BRL::Genboree::KB::Helpers::ViewsHelper::KB_MODEL
    @viewModelObj = BRL::Genboree::KB::KbDoc.new(viewModel)
  end

  # Validates the view document against the view model
  # Also makes sure that the property paths of any view prop does not contain any selector pattern
  # @param [Hash] viewDoc A hash representing the view payload
  # @return [Boolean] retVal
  def validate(viewDoc)
    @validationErrors = []
    valid = validateDoc(viewDoc, @viewModelObj)
    if(valid == true)
      # Make sure the viewProps in the view document are correct and do not contain illegal items
      viewDocObj = BRL::Genboree::KB::KbDoc.new(viewDoc)
      items = viewDocObj.getPropField('items', 'name.viewProps')
      labelToPropPathMap = {}
      items.each { |itemObj|
        propPath = itemObj['prop']['value']
        if(propPath =~ /(?:(?:\[\s*(?:\"|\/))|(?:\[\s*\]))/)
          @validationErrors  << "The property path: #{propPath} has a selector expression for selecting multiple items/properties. This is not allowed."
        end
        # Need to ensure two properties don't have the same label
        if(itemObj['prop'].key?('properties') and itemObj['prop']['properties'].key?('label'))
          label = itemObj['prop']['properties']['label']['value']
          if(labelToPropPathMap.key?(label))
            @validationErrors << "The label: #{label} for the property path: #{propPath} has already been seen for the property: #{labelToPropPathMap[label]}. You cannot use the same label for multiple property paths."
          else
            labelToPropPathMap[label] = propPath
          end
        end
      }
    end
    retVal = ( @validationErrors.empty? ? true : false )
    return retVal
  end

  end
end ; end ; end ; end # module BRL ; module Genboree ; module KB ; module Validators
