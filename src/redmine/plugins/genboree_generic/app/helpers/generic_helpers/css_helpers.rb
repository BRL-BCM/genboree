
# @todo use on runSearch output (dynamically generate CSS rules on view)
module GenericHelpers
  module CssHelpers
    # To have controller methods available in Views, Rails requires them to be declared as helper_methods.
    # Of course wherever they get included needs to also have the helper_method() method. Controllers
    #   and AbstractController::Helpers do. This should handle other cases appropriately.
    def self.included( obj )
      if( obj.respond_to?( :helper_method) )
        obj.helper_method :styleByAttrVals, :styleByAttr2Vals
      end
    end

    # Apply given stylings via 1+ [attribute=value] selectors build from given attribute
    #   and 1+ value.
    # @param [String] attr The HTML attribute which must have [exactly] a value from vals.
    # @param [Array<String>] vals One or more values for the attribute which can appear for elements in the page.
    # @param [Hash{Symbol,String}] cssStyles Hash of CSS style field Symbols to CSS style values.
    # @return [String] CSS string suitable for embedding within the page (e.g. via a View or something)
    def styleByAttrVals( attr, vals, cssStyles )
      return styleByAttr2Vals( { attr => vals }, cssStyles )
    end

    # Apply given stylings by providing a hash of html element attributes mapped to 1+ values.
    #   Generates a rule such that any element that has one of the value for one of the attributes will
    #   be styled as indicated.
    # @param [Hash{String, Array<String>}] attr2vals A hash of HTML attributes to their values.
    # @param [Hash{Symbol,String}] cssStyles Hash of CSS style field Symbols to CSS style values.
    # @return [String] CSS string suitable for embedding within the page (e.g. via a View or something)
    def styleByAttr2Vals( attr2vals, cssStyles )
      # Build the styleStr from hash of cssField : cssValue
      cssStyleStr = ''
      cssStyles.each_key { |cssField|
        cssValue = cssStyles[cssField]
        cssStyleStr << "#{cssField} : #{cssValue} ;\n"
      }

      # Build the 1+ selectors from hash of attribute=>values
      selector = ''
      attr2vals.each_key { |attr|
        vals = attr2vals[attr]
        vals.each_index { |idx|
          val = vals[idx]
          attr.to_s.strip!
          val.to_s.strip!
          escVal = val.gsub(/\"/, '\\"' )
          selector << "[#{attr}=\"#{escVal}\"]"
          selector << ', ' unless( idx >= (vals.size - 1) )
        }
      }
      css = "#{selector} {\n#{cssStyleStr}\n}"
      return css
    end
  end
end
