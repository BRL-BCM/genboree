require 'brl/util/util'
require 'brl/extensions/bson'
require 'brl/extensions/simpleDelegator'
require 'brl/genboree/kb/kbDoc'

module BRL ; module Genboree ; module KB ; module Producers
  class AbstractNestedTabbedProducer

    # COLUMNS will contain all of the core columns associated with the given doc
    COLUMNS = nil
    # What is SKIP_KEYS?
    SKIP_KEYS = nil
    # PROP_NAME_COL contains information about what the property "name" is
    PROP_NAME_COL = nil
    # SUBPROP_CONF gives us an indication of how we translate properties / items when producing our nested tabbed document
    # Here, properties are indicated by a hyphen (-) and items are indicated by an asterisk (*)
    SUBPROP_KEYS  = { 'properties' => '-', 'items' => '*' }

    attr_reader   :columns
    attr_accessor :result, :nameIdx, :headerIsComment, :errors
    attr_reader   :columns
    attr_accessor :docValid, :validator

    def initialize(*args)
      @columns = nil
      @allColumns = true
      @docValid = nil
      @headerIsComment = true
      @initialized = false
      init()
    end

    def init()
      # @errors will contain any errors we come across as we convert our document
      @errors = {}
      # @result will contain the final result (KbDoc in nested tabbed form)
      @result = nil
      # We set @docValid to false if @docValid is nil (so it wasn't manually set to true).
      # This allows calling code to deliberately set to true to avoid revalidation
      @docValid = false if(@docValid.nil?)
      # We set @initialized to true at the end of init().
      # If @initialized is false, we need to initialize our columns.
      # If @initialized is true BUT @columns is nil, then someone cleared all the columns (not OK!), so we have to reset them.
      unless(@initialized or !@columns.nil?)
        # If already initialized, then we're either set up for all columns or the user has overridden the columns to dump
        # If @columns is nil (unacceptable) someone has [inappropriately] cleared all of them, so we'll go back to the all column default.
        @allColumns = true
        # Defined columns first
        # - For _docs_ there are only columns as defined by the model
        # - For _models_ there may be some additional non-core columns (additional non-core property definition fields)
        #   . So for models, will need to discover all non-core columns and add them to this list! (JIT)
        @columns = self.class::COLUMNS.dup
      end
      # Next, we look in our core columns (@columns) and grab the index of the "name" column - its name is dictated by PROP_NAME_COL 
      @nameIdx = @columns.index(self.class::PROP_NAME_COL)
      # If the list of core columns (@columns) does not contain a "name" column, we raise an error.
      unless(@nameIdx)
        raise "ERROR: The list of columns MUST include the property name key (#{self.class::PROP_NAME_COL.inspect})"
      end
      # Finally, since we're done initializing our producer, we set @initialized to be true.
      @initialized = true
    end

    # This method allows us to set @columns to a custom array of columns (given in collArray) instead of the columns found in COLUMNS + extraCols
    # @param [Array] collArray custom array of column names
    # @return [nil]
    def columns=(collArray)
      @allColumns = false # using custom array of columns instead
      @columns = collArray
    end

    # This method produces a nested tabbed document from a KB doc
    # @param [Array, Hash] rawDoc raw document that will be converted into nested tabbed document  
    # @param [boolean] modelInHashOrArray boolean that tells us whether we're producing a model (in hash/array) form.  If that's the case, we don't want to cast it into a KbDoc.
    # @return [Array] converted nested tabbed doc
    def produce(rawDoc, modelInHashOrArray = false)
      # Initialize producer with init() method
      init()
      # @result will contain our final result (nested tabbed document)
      @result = []
      # doc will hold a KbDoc version of our rawDoc (Array or Hash)
      unless(modelInHashOrArray)
        doc = KbDoc.new(rawDoc)
      else
        doc = rawDoc
      end
      # This will look through the doc and see whether any keys are '_id' or :_id - it clears those since they're just internal Mongo ID keys (not important for user).
      doc.cleanKeys!(['_id', :_id]) unless(modelInHashOrArray)
      begin 
        # If we're going to use ALL columns (as indicated by @allColumns), then we find any non-core columns and add them to the columns list
        if(@allColumns)
          # We use the discoverNonCoreColumns method to find our extra columns (extraCols), and then we add those extra columns to @columns
          extraCols = ( discoverNonCoreColumns(doc).is_a?(Hash) ? discoverNonCoreColumns(doc).keys : discoverNonCoreColumns(doc) )
          @columns += extraCols
        end
        # We use the getSubDoc method to retrieve the very first property so that our visit method can create our tabbed document
        topProp = getSubDoc(doc)
        # Generate header
        header = header()
        # If produce() is given a block, then we enter the first branch below
        if(block_given?)
          # Start visiting the properties
          yield header
          # Visit & create yield-chain back to calling method's block
          visit(topProp) { |line| yield line }
          @result = true
        # Otherwise, we enter the second branch 
        else
          # Start visiting the properties
          @result << header()
          #$stderr.debugPuts(__FILE__, __method__, "DEBUG", ">>>>> Result (just header?):\n\n#{@result.inspect}\n\n")
          visit(topProp)
        end
      # We rescue if an error occurs
      rescue => err
        @result = nil
        $stderr.debugPuts(__FILE__, __method__, "ERROR", "ERROR: #{err} for doc:\n\n#{doc.inspect}\n\nError trace:\n\n#{err.backtrace.join("\n")}\n\n")
      end
      # At the end, we return @result as our new nested tabbed document (converted from KbDoc)
      return @result
    end

    # This method adds the appropriate amount of nesting to a given record's property 
    # @param [Array] rec current record
    # @param [String] nesting current amount of nesting
    # @return [Array] rec with added nesting
    def addNesting(rec, nesting)
      # If some amount of nesting is given and it contains non-white space characters, then we need to add that nesting to our record's property.
      if(nesting and nesting =~ /\S/)
        rec[@nameIdx] = "#{nesting} #{rec[@nameIdx]}"
      end
      # Then, we return rec with the nesting included
      return rec
    end

    # This method will return information about any errors that crop up when producing
    # @return [String] list of errors that occurred (and associated line numbers)
    def errorSummaryStr()
      # If we find errors, add them to retVal
      if(@errors.is_a?(Hash) and !@errors.empty?)
        retVal = ''
        @errors.keys.sort.each { |lineno|
          retVal << "LINE #{lineno} : #{@errors[lineno]}\n"
        }
      else
        retVal = nil
      end
      # We return retVal at the end - it's either nil (no errors) or contains errors (and associated line numbers)
      return retVal
    end

    # ------------------------------------------------------------------
    # OVERRIDABLE METHODS - override if needed/appropriate
    # ------------------------------------------------------------------

    # Returns array of columns (fields) not already known.
    #   Mainly need override for representing @models@, where some property definitions have non-core fields.
    def discoverNonCoreColumns(doc)
      return []
    end

    # ------------------------------------------------------------------
    # ABSTRACT INTERFACE METHODS - to be implemented in sub-classes
    # ------------------------------------------------------------------

    def getSubDoc(doc)
      raise NotImplementedError, "ERROR: this class (#{self.class}) does not implement the abstract interface method '#{__method__}', but is required to do so."
    end

    def makeValidator()
      raise NotImplementedError, "ERROR: this class (#{self.class}) does not implement the abstract interface method '#{__method__}', but is required to do so."
    end

    def validateDoc(doc)
      raise NotImplementedError, "ERROR: this class (#{self.class}) does not implement the abstract interface method '#{__method__}', but is required to do so."
    end

    def header()
      raise NotImplementedError, "ERROR: this class (#{self.class}) does not implement the abstract interface method '#{__method__}', but is required to do so."
    end

    def dump(prop, nesting)
      raise NotImplementedError, "ERROR: this class (#{self.class}) does not implement the abstract interface method '#{__method__}', but is required to do so."
    end

    def visit(prop, nesting='')
      raise NotImplementedError, "ERROR: this class (#{self.class}) does not implement the abstract interface method '#{__method__}', but is required to do so."
    end

    # ------------------------------------------------------------------
    # HELPERS
    # ------------------------------------------------------------------

    # This method updates the nesting for a given property
    # @param [Hash] prop current property 
    # @param [String] currentNesting current nesting for current property
    # @param [Hash] propDef property definition for current property
    # @return [String] new nesting for current property
    def updateNesting(prop, currNesting, propDef=nil)
      # We initially set retVal to be the current nesting
      retVal = currNesting
      # If prop and currNesting both have values, and prop acts as a hash, then we proceed
      if(prop)
        if(currNesting)
          unless(propDef)
            if(prop.acts_as?(Hash))
              # If our current property has an items key, then we add the SUBPROP_KEY associated with items (*) to the current nesting for the property
              if(prop.key?('items'))
                retVal = "#{currNesting}#{self.class::SUBPROP_KEYS['items']}"
              # Otherwise, our current property has a properties key (or is a leaf), and we add the SUBPROP_KEY associated with properties (-) to the current nesting for the property
              else
                retVal = "#{currNesting}#{self.class::SUBPROP_KEYS['properties']}"
              end
            end
          else 
            if(prop.acts_as?(Hash))
              # If our current property has an items key, then we add the SUBPROP_KEY associated with items (*) to the current nesting for the property
              if(propDef["items"])
                retVal = "#{currNesting}#{self.class::SUBPROP_KEYS['items']}"
              # Otherwise, our current property has a properties key (or is a leaf), and we add the SUBPROP_KEY associated with properties (-) to the current nesting for the property
              else
                retVal = "#{currNesting}#{self.class::SUBPROP_KEYS['properties']}"
              end
            end              
          end
        # If currNesting is empty, then our current nesting is nil so we set retVal to be blank (root property)
        else
          retVal = ''
        end
      end
      # Finally, we return retVal at the end as our new updated nesting for the current property
      return retVal
    end
  end
end ; end ; end ; end # module BRL ; module Genboree ; module KB ; module Converters
