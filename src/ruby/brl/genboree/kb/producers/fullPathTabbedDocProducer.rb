require 'brl/util/util'
require 'brl/extensions/bson'
require 'brl/extensions/simpleDelegator'
require 'brl/genboree/kb/kbDoc'
require 'brl/genboree/kb/validators/modelValidator'
require 'brl/genboree/kb/producers/nestedTabbedDocProducer'

module BRL ; module Genboree ; module KB ; module Producers
  class FullPathTabbedDocProducer < NestedTabbedDocProducer

    def addNesting(rec, nesting)
      # Unlike nestedTabbedDocProducer, nesting here already includes the record's prop name.
      if(nesting and nesting =~ /\S/)
        rec[@nameIdx] = nesting
      end
      return rec
    end

    # ------------------------------------------------------------------
    # ABSTRACT INTERFACE METHODS - to be implemented in sub-classes
    # ------------------------------------------------------------------

    def visit(subDoc, nesting='')
      if(subDoc.acts_as?(Hash))
        if(subDoc.respond_to?(:ordered_keys))
          subDocKeys = subDoc.ordered_keys
        else # probably regular ruby Hash...ok, but has issue
          subDocKeys = subDoc.keys
          if(nesting.nil?)
            $stderr.puts "WARNING: The doc object does not support maintenance of hash-key order. Cannot guaranty properties will appear in the same order from one production to the next. (Underlaying class is likely a Hash instead of, say, a BSON::OrderedHash)"
          end
        end
        subDocKeys.each { |subProp|
          newNesting = ( nesting =~ /\S/ ? "#{nesting}.#{subProp}" : subProp )
          valObj = subDoc[subProp]
          # Dump prop & value
          recStr = dump(subDoc, subProp, newNesting)
          if(recStr)
            if(block_given?)
              yield recStr
            else
              @result << recStr
            end
          end
          # Try to visit the sub-props or sub-items, assuming we can get at them (non-nil value obj)
          if(valObj)
            self.class::SUBPROP_KEYS.each_key { |subpropField|
              if(valObj.key?(subpropField))
                subPropContent = valObj[subpropField]
                if(block_given?) # Create yield-chain back to calling method's block
                  visit(subPropContent, newNesting) { |line| yield line }
                else
                  visit(subPropContent, newNesting)
                end
              end
            }
          end

        }
      elsif(subDoc.acts_as?(Array))
        index = 0
        if(block_given?)
          subDoc.each { |subDocElem| # Create yield-chain back to calling method's block
            nesting += ".[#{index}]"
            visit(subDocElem, nesting) { |line| yield line }
            nesting.chomp!(".[#{index}]")
            index += 1
          }
        else
          subDoc.each { |subDocElem|
            nesting += ".[#{index}]"
            visit(subDocElem, nesting)
            nesting.chomp!(".[#{index}]")
            index += 1
          }
        end
      end
      return @result
    end
  end # class FullPathTabbedModelProducer < NestedTabbedModelProducer
end ; end ; end ; end
