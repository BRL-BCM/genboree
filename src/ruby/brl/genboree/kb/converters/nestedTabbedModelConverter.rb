require 'brl/util/util'
require 'brl/genboree/kb/converters/abstractNestedTabbedConverter'

module BRL ; module Genboree ; module KB ; module Converters
  class NestedTabbedModelConverter < AbstractNestedTabbedConverter

    REQUIRED_COLS = [ :name, :identifier ]
    KNOWN_COLS    =
    {
      :name => true,
      :identifier => true,
      :domain => true,
      :required => true,
      :unique => true,
      :category => true,
      :fixed => true,
      :index => true,
      :default => true,
      :units => true,
      :description => true
    }

    # ------------------------------------------------------------------
    # HELPERS - mainly for use internally as parsing done, etc
    # ------------------------------------------------------------------

    # ABSTRACT INTERFACE METHOD.
    def createPropObj(propInfo, rec, index=-1)
      #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "  BEGIN: Create prop def obj for info: #{propInfo.inspect}")
      propName      = propInfo[:name].strip
      propTreeInfo  = propInfo[:nesting].strip if(propInfo[:nesting])
      # Name handled specialy
      propDef = { 'name' => propName }
      # Extract property metadata
      @columns.each { |col|
        idx = @col2idx[col]
        unless(col == :name)
          propDefVal = rec[idx]
          if(propDefVal and propDefVal =~ /\S/)
            propDefVal.strip!
            propDef[col.to_s] = propDefVal.autoCast(true)
          end
        end
      }
      # Set up properties or items as appropriate
      if(propTreeInfo.nil? or propTreeInfo =~ /\-$/)
        propDef['properties'] = []
      elsif(propTreeInfo =~ /\*$/)
        propDef['items'] = []
      else # huh? unknown tree nesting character
        @errors[@lineno] = "Could not interpret the tree nesting info #{propTreeInfo.inspect} here; especially the last character, which is not '-' nor '*'."
      end
      #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "  END: Create prop def obj")
      return propDef
    end

    def addProp(prop, propInfo, ancestors)
      # Depth of this prop
      propDepth = (propInfo[:nesting] ? propInfo[:nesting].size : 0)
      # Depth of ancestors
      ancDepth = (ancestors.size  > 0 ? (ancestors.size - 1) : 0) # root is at 0 depth, so subtract 1. When empty, depth is 0 (not -1 obviously)
      if(propDepth == ancDepth)
        # This is sibling of last prop in ancestors. (or possibly the root in a special case)
        # Remove last prop from ancestors, it's a sibling and it's done
        ancestors.pop # works even when empty (i.e. at root level)
        # Need to add this new prop to the *parent*, which is now the last item in ancestors
        # - there will be no parent when adding the root node
        parentProp = ancestors.last
        if(parentProp)
          addStatus = addChild(parentProp, prop)
          unless(addStatus)
            @errors[@lineno] = "Could not determine how to add the property here to the model, given property records in the file up to this point. The property here is at depth #{propDepth.inspect} in the tree and should be added under the previous property (depth of properties at this point in the tree is #{ancDepth.inspect}). But the previous property has neither 'properties' nor 'items' available to add things. Unexpected; likely bug in code."
          end
        end
        # Regardless of whether added root not or a child node,
        #   add the curr prop to ancestors list. It's our current active prop.
        ancestors << prop
      elsif(propDepth < ancDepth)
        # Finished some possibly very nested branch and now jumping to shallow depths
        # Unravel the ancestors until find prop's depth and add prop
        while(propDepth < ancDepth and ancDepth >= 0)
          ancestors.pop
          ancDepth = (ancestors.size - 1)
        end
        # We've reached a sibling of this prop. Remove and replace with this prop.
        ancestors.pop
        # Need to add this new prop to the *parent*, which is now the last item in ancestors
        # - Cannot be adding the root node here in this scenario, so MUST be a last prop (i.e. there must be a parent at this point)
        parentProp = ancestors.last
        parentProp = ancestors.last
        if(parentProp)
          addStatus = addChild(parentProp, prop)
          unless(addStatus)
            @errors[@lineno] = "Could not determine how to add the property here to the model, given property records in the file up to this point. The property here is at depth #{propDepth.inspect} in the tree and should be added under the previous property (depth of properties at this point in the tree is #{ancDepth.inspect}. But the previous property has neither 'properties' nor 'items' available to add things. Unexpected; likely bug in code."
          end
        else
          @errors[@lineno] = "Could not add property here to the model because it appears to be a root-level property. The model jumps from deep within the nested document all the way to the root/top-level property somehow. Either model is wrong/bad or there's some bad parsing code being triggered by this model."
        end
        # Add the curr prop to ancestors list. It's our current active prop.
        ancestors << prop
      elsif(propDepth == (ancDepth + 1))
        # This is a child of the last prop in ancestors.
        # Add it to properties or items of last prop in ancestors
        parentProp = ancestors.last
        addStatus = addChild(parentProp, prop)
        unless(addStatus)
          @errors[@lineno] = "Could not determine how to add the property here to the model, given property records in the file up to this point. The property here is at depth #{propDepth.inspect} in the tree and should be added under the previous property (depth of properties at this point in the tree is #{ancDepth.inspect}. But the previous property has neither 'properties' nor 'items' available to add things. Unexpected; likely bug in code."
        end
        # It becomes the new last prop
        ancestors << prop
      elsif(propDepth > (ancDepth + 1))
        # ERROR! This prop is a grandchild or Nth-great-grandchild of the last prop
        #   in ancestors and we've skipped the offspring and maybe some grandchild, etc etc!
        @errors[@lineno] = "The property defined here (#{propInfo[:name].inspect}) has bad tree nesting information. At this point in the model, we are at a depth of #{ancDepth.inspect}. Yet the property here indicates is should be at depth #{propDepth.inspect}...how did we jump deeper without the intervening #{(propDepth - ancDepth) - 1} properties??? The data provided here cannot produce a sensible model."
      else
        # ERROR! Some case we didn't handle or think about. How got here? Should be wrong.
        @errors[@lineno] = "Unexpectedly, the depth of the current property is #{propDepth.inspect} while the depth of the previous property is #{ancDepth.inspect} and this is not one of the expected cases handled by the parser. Code bug?"
      end
      return ancestors
    end

    # ABSTRACT INTERFACE METHOD.
    def addChild(parentProp, childProp)
      retVal = nil
      if(parentProp)
        if(parentProp.key?('properties'))
          parentProp['properties'] << childProp
          retVal = parentProp
        elsif(parentProp.key?('items'))
          parentProp['items'] << childProp
          retVal = parentProp
        else # huh? neither properties or items available
          retVal = nil
        end
      end
      return retVal
    end

    # ABSTRACT INTERFACE METHOD.
    def cleanResult(indent=0, doc=nil)
      cleanPropDef(@result, indent)
      return @result
    end

    def cleanPropDef(propDef, indent=0)
      # DOMAIN: Set explicit domain as part of conversion
      #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "#{'.'*indent}#{propDef['name']}")
      propDomain = propDef['domain']
      unless(propDomain and propDomain =~ /\S/)
        propDef['domain'] = 'string'
      end
      # PROPERTIES: Remove any that are empty
      # - empty properties lists are generated automatically during conversion ; clean them out
      # - note: we DON'T clean empty items lists (i.e. list --* props with NO sub-item defined) since those are model errors!
      propDefProps = propDef['properties']
      if(propDefProps)
        unless(propDefProps.empty?)
          propDefProps.each { |subPropDef|
            cleanPropDef(subPropDef, indent + 1)
          }
        else
          propDef.delete('properties')
        end
      end
      # Recursive visit to any 'items' of course
      propDefItems = propDef['items']
      if(propDefItems)
        propDefItems.each { |subPropDef|
          cleanPropDef(subPropDef, indent + 1)
        }
      end
      return propDef
    end
  end # class NestedTabbedModelConverter
end ; end ; end ; end # module BRL ; module Genboree ; module KB ; module Converters
