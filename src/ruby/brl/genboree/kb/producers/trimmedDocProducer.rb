require 'brl/util/util'
require 'brl/extensions/bson'
require 'brl/extensions/simpleDelegator'
require 'brl/genboree/kb/kbDoc'
require 'brl/genboree/kb/validators/docValidator'
require 'brl/genboree/kb/producers/abstractNestedTabbedProducer'
require 'brl/genboree/kb/propSelector'

module BRL ; module Genboree ; module KB ; module Producers
  class TrimmedDocProducer < AbstractNestedTabbedProducer

    # The core columns associated with a nested tabbed doc are "property" and "value"
    COLUMNS       = [ nil ] # not relevant here, just keeping happy
    SUBPROP_KEYS  = { 'properties' => '', 'items' => '', 'value' => '' }

    attr_accessor :opts

    def initialize(*args)
      super(*args)
      if(args.is_a?(Array) and args.last.is_a?(Hash))
        @opts = args.last
      else
        @opts = {}
      end
    end

    # @note Overridding only to dup and return a modified rawDoc.
    # This method produces a nested tabbed document from a KB doc
    # @param [Array, Hash] rawDoc raw document that will be converted into nested tabbed document
    # @param [boolean] modelInHashOrArray boolean that tells us whether we're producing a model (in hash/array) form.  If that's the case, we don't want to cast it into a KbDoc.
    # @return [Array] converted nested tabbed doc
    def produce(rawDoc, modelInHashOrArray = false)
      dupDoc = rawDoc.deep_clone
      super(dupDoc, modelInHashOrArray)
      return dupDoc
    end

    # ------------------------------------------------------------------
    # ABSTRACT INTERFACE METHODS - to be implemented in sub-classes
    # ------------------------------------------------------------------

    # This method returns the current doc
    # @param [KbDoc] doc current doc
    # @return [KbDoc] current doc
    def getSubDoc(doc)
      return doc
    end

    # This method creates a validator for validating a document against our model
    # @return [DocValidator] validator for checking document against model
    def makeValidator()
      # We will not be validating. In fact, we will be corrupting
      return nil
    end

    # This method validates a given document against our model
    # @param [KbDoc] document that will be checked
    # @return [boolean] boolean that tells us whether doc is valid (true if it is, false if it isn't)
    def validateDoc(doc)
      # We will not be validating. Everything is valid.
      return true
    end

    # This method converts our columns (found in @columns) into a header line for our nested tabbed doc
    # @return [String] header line for nested tabbed doc
    def header()
      # There is no header because we are making a new KbDoc.
      return nil
    end

    # This method will create the tabbed line for a particular property / value pair (held in rec)
    # @return [String] tabbed line containing particular property / value pair
    def dump(subDoc, propName, nesting)
      # Not dumping, making a new doc
      return nil
    end

    # This method will create the nested tabbed doc (recursively) by visiting each sub document and dumping contents of each property into own tabbed line
    # @param [Hash or Array] subDoc current sub document
    # @param [String] nesting current nesting
    # @param [String] previousPath the previous path (used for updating nesting accurately)
    # @return [String] converted document
    def visit(subDoc, nesting=nil, previousPath=nil)
      # If subDoc acts as a hash, we proceed (otherwise, we can't!)
      if(subDoc.acts_as?(Hash))
        # If subDoc responds to the method :ordered_keys, then we will grab the ORDERED keys from the hash.
        # I think this only works with BSON::OrderedHash, so not regular hash.
        if(subDoc.respond_to?(:ordered_keys))
          subDocKeys = subDoc.ordered_keys
        # Otherwise, we just have a regular hash, so we just grab its (unordered) keys.
        else
          subDocKeys = subDoc.keys
        end
        # We traverse each of the keys gathered above for our sub document - each is a sub property of that document!
        subDocKeys.each { |subProp|
          # Skip sub property if it's a Mongo ID (messes up bulkUpload in AbstractHelper)
          next if(subProp == '_id')
          # We grab the value object associated with the current sub property
          valObj = subDoc[subProp]

          # Try to handle this special case first. (Really this needs a model to check against to do it properly/correctly).)
          # Don't even bother checking for content if this known special case (has empty items list while its value is 0, probably from numItems)
          if( @opts[:aggressive] and valObj.key?('value') and valObj['value'] == 0 and valObj.key?('items') and (valObj['items'].nil? or valObj['items'].empty?) )
            subDoc.delete(subProp)
          else # Not that case, do generic visit and testing
            # Visit the subprop contents
            self.class::SUBPROP_KEYS.each_key { |subpropField|
              # We then check to see whether our value object contains the current sub property key.
              if(valObj.key?(subpropField))
                # If it does, then we grab the content associated with that sub property key and set it equal to subPropContent.
                # This will be fed into our visit method, recursively, as our new sub document.
                subPropContent = valObj[subpropField]
                subPropEmpty = visit(subPropContent)
                if(subPropEmpty == :empty) # subprop content now empty due to recursive trim, remove it
                  valObj.delete(subpropField)
                end
              end
            }

            # Now that we recursively trimmed this subProp, does it still have actual content?
            # Or is it itself now need to be removed because all descendent content was trimmed out?
            propHasContent = false
            self.class::SUBPROP_KEYS.each_key { |subpropField|
              # We then check to see whether our value object contains the current sub property key.
              if(valObj.key?(subpropField))
                # If it does, then we grab the content associated with that sub property key and set it equal to subPropContent.
                subPropContent = valObj[subpropField]
                if( !subPropContent.nil? and (!subPropContent.respond_to?(:'empty?') or !subPropContent.empty? ) )
                  propHasContent = true
                  break
                end
              end
            }
            unless(propHasContent)
              subDoc.delete(subProp)
            end
          end
        }
        # Is there anything left in the subDoc?
        retVal = (subDoc.empty? ? :empty : :notEmpty)
      elsif(subDoc.acts_as?(Array)) # Otherwise, if our sub document acts as an array instead of a hash (items!), we proceed down this branch.
        subDoc.each { |subDocElem|
          visit(subDocElem)
        }
        # Did we clean out all the items because they had no actual content?
        if(subDoc.all? { |item| (item.nil? or item.empty?) })
          retVal = :empty
        else
          retVal = :notEmpty
        end
      end
      # At the end of our "visit", we return @result with new, additional elements consisting of tabbed lines (property / value pairs).
      return retVal
    end
  end # class NestedTabbedModelProducer < AbstractNestedTabbedProducer
end ; end ; end ; end
