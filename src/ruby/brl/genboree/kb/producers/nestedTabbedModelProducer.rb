require 'brl/util/util'
require 'brl/extensions/bson'
require 'brl/extensions/simpleDelegator'
require 'brl/genboree/kb/kbDoc'
require 'brl/genboree/kb/validators/modelValidator'
require 'brl/genboree/kb/producers/abstractNestedTabbedProducer'

module BRL ; module Genboree ; module KB ; module Producers
  class NestedTabbedModelProducer < AbstractNestedTabbedProducer

    COLUMNS       = [ 'name', 'domain', 'default', 'identifier', 'required', 'unique', 'units', 'category', 'fixed', 'index', 'description' ]
    PROP_NAME_COL = 'name'

    # ------------------------------------------------------------------
    # ABSTRACT INTERFACE METHODS - to be implemented in sub-classes
    # ------------------------------------------------------------------

    def getSubDoc(modelDoc)
      if(modelDoc.is_a?(BRL::Genboree::KB::KbDoc))
        model = modelDoc.getPropVal('name.model') rescue nil
        if(model.nil?)
          @errors[0] = "ERROR: The doc parameter is a full BRL::Genboree::KB::KbDoc document, but does not have a valid 'model' sub-property where the actual model data can be found."
        end
      else
        model = modelDoc
      end
      return model
    end

    def makeValidator()
      @validator ||= BRL::Genboree::KB::Validators::ModelValidator.new()
      return @validator
    end

    def validateDoc(doc)
      unless(@docValid)
        makeValidator()
        modelValid = @validator.validateModel(doc)
        if(modelValid)
          @docValid = true
        else
          @docValid = false
        end
      end
      return @docValid
    end

    def header()
      return "#{@headerIsComment ? '#' : ''}#{@columns.join("\t")}"
    end

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
      # Add nesting
      rec = addNesting(rec, nesting)
      retVal = rec.join("\t")
      return retVal
    end

    def visit(prop, nesting=nil)
      newNesting = updateNesting(prop, nesting)
      if(prop.acts_as?(Hash))
        # Dump prop definition
        recStr = dump(prop, newNesting)
        if(recStr)
          if(block_given?)
            yield recStr
          else
            @result << recStr
          end
        end
        # Regardless, let's try to visit the sub-props or sub-items
        self.class::SUBPROP_KEYS.each_key { |subpropField|
          #nestChar = self.class::SUBPROP_KEYS[subpropField]
          if(prop.key?(subpropField))
            subPropContent = prop[subpropField]
            if(block_given?) # Create yield-chain back to calling method's block
              #visit(subPropContent, "#{nesting}#{nestChar}") { |line| yield line }
              visit(subPropContent, newNesting) { |line| yield line }
            else
              #visit(subPropContent, "#{nesting}#{nestChar}")
              visit(subPropContent, newNesting)
            end
          end
        }
      elsif(prop.acts_as?(Array))
        if(block_given?)
          prop.each { |subProp| # Create yield-chain back to calling method's block
            visit(subProp, newNesting) { |line| yield line }
          }
        else
          prop.each { |subProp|
            visit(subProp, newNesting)
          }
        end
      end
      return @result
    end
  end # class NestedTabbedModelProducer < AbstractNestedTabbedProducer
end ; end ; end ; end
