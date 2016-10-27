require 'brl/util/util'
require 'brl/extensions/bson'
require 'brl/extensions/simpleDelegator'
require 'brl/genboree/kb/kbDoc'
require 'brl/genboree/kb/validators/modelValidator'
require 'brl/genboree/kb/producers/nestedTabbedModelProducer'

module BRL ; module Genboree ; module KB ; module Producers
  class FullPathTabbedModelProducer < NestedTabbedModelProducer

    COLUMNS  = [ 'name', 'domain', 'default', 'identifier', 'required', 'unique', 'units', 'category', 'fixed', 'index', 'description', 'isItemList' ]

    attr_accessor :isItemListIdx

    def init()
      super()
      @isItemListIdx = @columns.index('isItemList')
    end

    def addNesting(rec, nesting)
      if(nesting and nesting =~ /\S/)
        rec[@nameIdx] = "#{nesting}.#{rec[@nameIdx]}"
      end
      return rec
    end

    # ------------------------------------------------------------------
    # ABSTRACT INTERFACE METHODS - to be implemented in sub-classes
    # ------------------------------------------------------------------

    def dump(propDef, nesting)
      rec = Array.new(@columns.size)
      @columns.each_index { |ii|
        colName = @columns[ii]
        if(propDef.key?(colName))
          rec[ii] = propDef[colName]
        else
          rec[ii] = nil
        end
      }
      # Set 'isItemList' value
      if(@isItemListIdx)
        rec[@isItemListIdx] = ( propDef.key?('items') ? true : false)
      end
      # Add nesting
      rec = addNesting(rec, nesting)
      retVal = rec.join("\t")
      return retVal
    end

    def visit(prop, nesting='')
      if(prop.acts_as?(Hash))
        # Dump prop definition
        recStr = dump(prop, nesting)
        if(recStr)
          if(block_given?)
            yield recStr
          else
            @result << recStr
          end
        end
        # Regardless, let's try to visit the sub-props or sub-items
        propName = prop[self.class::PROP_NAME_COL]
        self.class::SUBPROP_KEYS.each_key { |subpropField|
          if(prop.key?(subpropField))
            subPropContent = prop[subpropField]
            newNesting = ( nesting =~ /\S/ ? "#{nesting}.#{propName}" : propName )
            if(block_given?) # Create yield-chain back to calling method's block
              visit(subPropContent, newNesting) { |line| yield line }
            else
              visit(subPropContent, newNesting)
            end
          end
        }
      elsif(prop.acts_as?(Array))
        if(block_given?)
          prop.each_index { |ii|
            subProp = prop[ii]
            # Create yield-chain back to calling method's block
            visit(subProp, nesting) { |line| yield line }
          }
        else
          prop.each_index { |ii|
            subProp = prop[ii]
            visit(subProp, nesting)
          }
        end
      end
      return @result
    end
  end # class FullPathTabbedModelProducer < NestedTabbedModelProducer
end ; end ; end ; end
