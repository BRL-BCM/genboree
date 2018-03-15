require 'brl/util/util'
require 'brl/genboree/kb/converters/abstractNestedTabbedConverter'
require 'brl/genboree/kb/kbDoc'
require 'brl/genboree/kb/propSelector'

module BRL ; module Genboree ; module KB ; module Converters
  class NestedTabbedDocConverter < AbstractNestedTabbedConverter

    REQUIRED_COLS = [ :property, :value ]
    REQUIRED_BULK_COLS = [ :domain ]
    KNOWN_COLS    =
    {
      :property => true,
      :value => true,
      :domain => true
    }    

    # ------------------------------------------------------------------
    # HELPERS - mainly for use internally as parsing done, etc
    # ------------------------------------------------------------------

    # ABSTRACT INTERFACE METHOD.
    def createPropObj(propInfo, rec, index=-1)
      #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "  BEGIN: Create prop def obj for info: #{propInfo.inspect}")
      propName      = propInfo[:name].strip
      propTreeInfo  = propInfo[:nesting].strip if(propInfo[:nesting])
      # Create prop object using name
      valObj = {}
      prop = { propName => valObj }
      # Is there a value? (even if empty)
      if(index==-1)
        valIdx = @col2idx[:value]
      else
        valIdx = index
      end
      propVal = rec[valIdx]
      propVal = '' unless(propVal and propVal =~ /\S/)
      propVal.gsub!("\\n", "\n")
      propVal.gsub!("\\t", "\t")
      valObj['value'] = propVal
      # Set up properties or items as appropriate
      if(propTreeInfo.nil? or propTreeInfo =~ /\-$/)
        valObj['properties'] = {}
      elsif(propTreeInfo =~ /\*$/)
        valObj['items'] = []
      else # huh? unknown tree nesting character
        @errors[@lineNo] = "Could not interpret the tree nesting info #{propTreeInfo.inspect} here; especially the last character, which is not '-' nor '*'."
      end
      #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "  END: Create prop def obj")
      return prop
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
            @errors[@lineNo] = "Could not determine how to add the property here to the document, given property records in the file up to this point. The property here is at depth #{propDepth.inspect} in the tree and should be added under the previous property (depth of properties at this point in the tree is #{ancDepth.inspect}). But the previous property has neither 'properties' nor 'items' available to add things. Unexpected; likely bug in code."
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
            @errors[@lineNo] = "Could not determine how to add the property here to the document, given property records in the file up to this point. The property here is at depth #{propDepth.inspect} in the tree and should be added under the previous property (depth of properties at this point in the tree is #{ancDepth.inspect}). But the previous property has neither 'properties' nor 'items' available to add things. Unexpected; likely bug in code."
          end
        else
          @errors[@lineNo] = "Could not add property here to the document because it appears to be a root-level property. The document jumps from deep within the nested document all the way to the root/top-level property somehow. Either document is wrong/bad or there's some bad parsing code being triggered by this document."
        end
        # Add the curr prop to ancestors list. It's our current active prop.
        ancestors << prop
      elsif(propDepth == (ancDepth + 1))
        # This is a child of the last prop in ancestors.
        # Add it to properties or items of last prop in ancestors
        parentProp = ancestors.last
        addStatus = addChild(parentProp, prop)
        unless(addStatus)
          @errors[@lineNo] = "Could not determine how to add the property here to the document, given property records in the file up to this point. The property here is at depth #{propDepth.inspect} in the tree and should be added under the previous property (depth of properties at this point in the tree is #{ancDepth.inspect}). But the previous property has neither 'properties' nor 'items' available to add things. Unexpected; likely bug in code."
        end
        # It becomes the new last prop
        ancestors << prop
      elsif(propDepth > (ancDepth + 1))
        # ERROR! This prop is a grandchild or Nth-great-grandchild of the last prop
        #   in ancestors and we've skipped the offspring and maybe some grandchild, etc etc!
        @errors[@lineNo] = "The property here (#{propInfo[:name].inspect}) has bad tree nesting information. At this point in the document, we are at a depth of #{ancDepth.inspect}. Yet the property here indicates is should be at depth #{propDepth.inspect}...how did we jump deeper without the intervening #{(propDepth - ancDepth) - 1} properties??? The data provided here cannot produce a sensible document."
      else
        # ERROR! Some case we didn't handle or think about. How got here? Should be wrong.
        @errors[@lineNo] = "Unexpectedly, the depth of the current property is #{propDepth.inspect} while the depth of the previous property is #{ancDepth.inspect} and this is not one of the expected cases handled by the parser. Code bug?"
      end
      return ancestors
    end

    # ABSTRACT INTERFACE METHOD.
    def addChild(parentProp, childProp)
      retVal = nil
      if(parentProp)
        # Key parentProp elements
        parentPropName = parentProp.keys.first
        parentValObj = parentProp[parentPropName]
        parentSubProps = parentValObj['properties']
        parentSubItems = parentValObj['items']
        # Key childProp elements
        childPropName = childProp.keys.first
        childValObj = childProp[childPropName]
        # Figure out where to add child
        if(parentSubProps.acts_as?(Hash))
          parentSubProps[childPropName] = childValObj
          retVal = parentProp
        elsif(parentSubItems.acts_as?(Array))
          parentSubItems << childProp
          retVal = parentProp
        else # huh? neither properties or items available
          retVal = nil
        end
      end
      return retVal
    end

    # ABSTRACT INTERFACE METHOD.
    def cleanResult(indent=0, doc=nil)
      unless(doc)
        valObj = @result.values.first
        cleanValObj(valObj, indent)
        return @result
      else
        valObj = doc.values.first
        cleanValObj(valObj, indent)
        return valObj
      end
    end

    def cleanValObj(propValObj, indent=0)
      # PROPERTIES: Remove any that are empty
      # - empty properties lists are generated automatically during conversion ; clean them out
      # - note: we DON'T clean empty items lists (i.e. list --* props with NO sub-item defined) since those are model errors!
      propSubProps = propValObj['properties'] rescue nil
      if(propSubProps)
        unless(propSubProps.empty?)
          propSubProps.each_key { |subPropName|
            subPropVal = propSubProps[subPropName]
            cleanValObj(subPropVal, indent + 1)
          }
        else
          propValObj.delete('properties')
        end
      end
      # Recursive visit to any 'items' of course
      propSubItems = propValObj['items'] rescue nil
      if(propSubItems)
        unless(propSubItems.empty?)
          propSubItems.each { |subPropDef|
            subPropVal = subPropDef[subPropDef.keys.first]
            cleanValObj(subPropVal, indent + 1)
          }
        else
          propValObj.delete('items')
        end
      end
      return propValObj
    end
  end # class NestedTabbedDocConverter
end ; end ; end ; end # module BRL ; module Genboree ; module KB ; module Converters
