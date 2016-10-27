require 'brl/util/util'
require 'brl/extensions/bson'
require 'brl/genboree/kb/kbDoc'
require 'brl/genboree/kb/validators/modelValidator'
require 'brl/genboree/kb/validators/docValidator'

module BRL ; module Genboree ; module KB ; module Producers
  class AbstractProducer

    attr_accessor :model, :emissionCallback, :result, :errors
    attr_accessor :validator, :modelValidator
    attr_reader :docValid

    # CONSTRUCTOR.
    # @param [Hash,BRL::Genboree::KB::KbDoc] model The model @Hash@ or full @KbDoc@ wrapped model for the
    #   doc to be rendered.
    # @param [Proc,nil] emissionCallback If want to be be *streamed* the chunks as they are generated,
    #   which is good for saving RAM or dealing with massive inputs/outputs, pass in a {Proc} callback that takes
    #   one argument, a line/chunk being emitted. If @nil@, all chunks will be accumulated in an @Array@
    #   and availble from @result.
    # @param [Array] args To aid subclass design & usage while keeping a uniform interface any specific arguments can be
    #   passed as well.
    def initialize(model, emissionCallback=nil, *args)
      raise ArgumentError, "ERROR: emissionCallback must either be a Proc that takes a single string arg or nil for non-streaming mode." unless(emissionCallback.nil? or emissionCallback.is_a?(Proc))
      @modelValidator = BRL::Genboree::KB::Validators::ModelValidator.new()
      raise ArgumentError, "ERROR: model provided fails validation. Not a proper, compliant model." unless(@modelValidator.validateModel(model))
      @emissionCallback = emissionCallback
      @model = model
      @modelsHelper = BRL::Genboree::KB::Helpers::ModelsHelper.new(nil)
      init()
    end

    # ------------------------------------------------------------------
    # ABSTRACT INTERFACE METHODS - to be implemented in sub-classes
    # ------------------------------------------------------------------

    # Generate the initial 'header' string for the doc. Open XML/HTML tags, add comments, etc. Generally not
    #   for rendering any content of the root property of the doc but rather to just begin the doc--enterSubDoc,
    #   renderValue, exitSubDoc will be called specically for the root nodes as will events for ALL the recursive
    #   contents of the doc [*before* exitSubDoc is called for the root node].
    # @param [BRL::Genboree::KB::KbDoc] doc Document being dumped in some other format.
    # @param [Hash] opts Additional options/info Hash, possibly subclass-specific, changes to hash
    #   contents will propagate forward which is useful for accumulating/decummulating array stacks and such.
    # @return [String] The header string.
    def enterDoc(doc, opts)
      raise NotImplementedError, "ERROR: this class (#{self.class}) does not implement the abstract interface method '#{__method__}', but is required to do so."
    end

    # Generate terminal 'footer' string for the doc. Close XML/HTML tags, add comments, etc.
    # @param [BRL::Genboree::KB::KbDoc] doc Document being dumped in some other format.
    # @param [Hash] opts Additional options/info Hash, possibly subclass-specific, changes to hash
    #   contents will propagate forward which is useful for accumulating/decummulating array stacks and such.
    # @return [String] The footer string.
    def exitDoc(doc, opts)
      raise NotImplementedError, "ERROR: this class (#{self.class}) does not implement the abstract interface method '#{__method__}', but is required to do so."
    end

    # Generate any opening xml/html tags etc for starting a subDoc. Generally, not for rendering the value display
    #  (@see #renderValue, #renderItem). Keep in mind that the subDoc may have a deep doc tree below it; we're doing DFS
    #   and pseudo-events via these enter/exit methods.
    # @param [Hash] doc The subdoc we're beging to recursively render.
    # @param [Array] propStack Current stack of properties, which starts at the root property down to the parent of @doc@
    # @param [Hash] opts Additional options/info Hash, possibly subclass-specific, changes to hash
    #   contents will propagate forward which is useful for accumulating/decummulating array stacks and such.
    # @return [String] The begin-subdoc emission string.
    def enterSubDoc(doc, proDef, propStack, opts)
      raise NotImplementedError, "ERROR: this class (#{self.class}) does not implement the abstract interface method '#{__method__}', but is required to do so."
    end

    # Generate any closing xml/html tags etc for closing a fully-visited subDoc. We're doing DFS and pseudo-events via these enter/exit methods.
    # @param (see #enterSubDoc)
    # @return [String] The end-subdoc emission string.
    def exitSubDoc(doc, proDef, propStack, opts)
      raise NotImplementedError, "ERROR: this class (#{self.class}) does not implement the abstract interface method '#{__method__}', but is required to do so."
    end

    # Generate any opening xml/html tags etc for starting an items list (e.g. open a <ol> or something). Other methods will be called as
    #   each item is visited. Keep in mind that the item may have a deep doc tree below it; we're doing
    #   DFS and pseudo-events via these enter/exit methods.
    # @param [Array<Hash>] items The array of items about to be DFS-visited.
    # @param [Array] propStack Current stack of properties, which starts at the root property down to the parent of @doc@
    # @param [Hash] opts Additional options/info Hash, possibly subclass-specific, changes to hash
    #   contents will propagate forward which is useful for accumulating/decummulating array stacks and such.
    # @return [String] The begin-items-list emission string
    def enterItems(items, proDef, propStack, opts)
      raise NotImplementedError, "ERROR: this class (#{self.class}) does not implement the abstract interface method '#{__method__}', but is required to do so."
    end

    # Generate any closing xml/html tags etc for starting an items list (e.g. open a </ol> or something).
    #   We're doing DFS and pseudo-events via these enter/exit methods.
    # @param (see #enterItems)
    # @return [String] The end-items-list emission string
    def exitItems(items, proDef, propStack, opts)
      raise NotImplementedError, "ERROR: this class (#{self.class}) does not implement the abstract interface method '#{__method__}', but is required to do so."
    end

    # Generate the opening xml/html tags etc for a subDoc about to be rendered within the context of an items list
    #   (e.g. <li>, </div> or something). Other methods will be called to render the actual subDoc value (see #renderValue) and the
    #   subDoc will be recursively visited to render what is below it.
    # @param (@see #renderValue)
    # @return [String] The begin-item emission string.
    def enterItem(doc, proDef, propStack, opts)
      raise NotImplementedError, "ERROR: this class (#{self.class}) does not implement the abstract interface method '#{__method__}', but is required to do so."
    end

    # Generate the closing xml/html tags etc for a subDoc about to be rendered within the context of an items list
    #   (e.g. </li>, </div> or something). Other methods will be called to render the actual subDoc value (see #renderValue) and the
    #   subDoc will be recursively visited to render what is below it.
    # @param (@see #renderValue)
    # @return [String] The end-item emission string.
    def exitItem(doc, proDef, propStack, opts)
      raise NotImplementedError, "ERROR: this class (#{self.class}) does not implement the abstract interface method '#{__method__}', but is required to do so."
    end

    # Generate the xml/thml tags etc for rendering the value of a subDoc. Subdoc may be a simple child property
    #   or an item in an item list. Keep in mind that the subDoc may have a deep doc tree below it; we're doing
    #   DFS and pseudo-events via these enter/exit methods.
    # @param [Object] value The value from the property's value object.
    # @param [Array] propStack Current stack of properties, which starts at the root property down to the parent of @doc@
    # @param [Hash] opts Additional options/info Hash, possibly subclass-specific, changes to hash
    #   contents will propagate forward which is useful for accumulating/decummulating array stacks and such.
    # @return [String] The value emission string.
    def renderValue(value, propDef, propStack, opts)
      raise NotImplementedError, "ERROR: this class (#{self.class}) does not implement the abstract interface method '#{__method__}', but is required to do so."
    end

    # ------------------------------------------------------------------
    # OVERRIDABLE METHODS - override if needed/appropriate
    # ------------------------------------------------------------------

    # Used by {#produce} to sanity check the @opts@ Hash. Can override to actually do some checking, but
    #   if so should start by calling @super()@ so parent checks are done.
    # @param [Hash] opts Additional options/info Hash, possibly subclass-specific, changes to hash
    #   contents will propagate forward which is useful for accumulating/decummulating array stacks and such.
    # @return [boolean] @true@ when sanity checks pass ; otherwise exception is to be raised, with information about failed check.
    # @raise [ArgumentError] When a sanity check fails (bad opts provided).
    def checkOpts(opts)
      return true
    end

    # This method creates a validator for validating a document against our model
    # @return [BRL::Genboree::KB::Validators::DocValidator] validator for checking document against model
    def makeValidator()
      # We create a DocValidator (unless one has already been created) and return it
      @validator ||= BRL::Genboree::KB::Validators::DocValidator.new()
      return @validator
    end

    # This method validates a given document against our model
    # @param [BRL::Genboree::KB::KbDoc] doc Document that will be checked.
    # @param [Hash] opts Additional options/info Hash, possibly subclass-specific, changes to hash
    #   contents will propagate forward which is useful for accumulating/decummulating array stacks and such.
    # @return [boolean] Indicating whether doc is valid (true if it is, false if it isn't)
    def validateDoc(doc, opts={})
      # Unless the doc has already been checked and is valid (or if we overrode @docValid because we don't want to use a model :)), we proceed
      unless(@docValid)
        # We create a validator to check our document
        makeValidator()
        # We check to see whether our doc is valid against @model
        valid = @validator.validateDoc(doc, @model)
        # If modelValid is true--or :CONTENT_NEEDED (??), then we set @docValid to be true
        if(valid)
          @docValid = true
        # Otherwise, we set @docValid to be false
        else
          @docValid = false
        end
      end
      # Finally, we return @docValid (to tell us whether doc is valid or not)
      return @docValid
    end

    # ------------------------------------------------------------------
    # CORE METHODS - generally do not override
    # ------------------------------------------------------------------

    # This method produces a formatted document string from a KB doc
    # @param [BRL::Genboree::KB::KbDoc] doc Document to be formatted
    # @param [Hash] opts Additional options/info Hash, possibly subclass-specific, changes to hash
    #   contents will propagate forward which is useful for accumulating/decummulating array stacks and such.
    # @return [Array<String>,boolean] If no block given then returns an Array with the lines (generally) of the formated doc ;
    #   else returns true assuming completed with no errors/exceptions.
    def produce(doc, opts={})
      # Initialize producer with init() method
      init()
      # Check the option hash and do any normalization
      checkOpts(opts)
      # @result will contain the string chunks of our formatted document (will have internal newlines as appropriate)
      @result = []
      doc = doc.deep_clone
      # This will look through the doc and see whether any keys are '_id' or :_id - it clears those since they're just internal Mongo ID keys (not important for user).
      doc.cleanKeys!(['_id', :_id])
      begin
        # Generate header
        header = enterDoc(doc, opts)
        emit(header)
        visitSubDoc(doc, [], opts)
        # Generate footer
        footer = exitDoc(doc, opts)
        emit(footer)
      # We rescue if an error occurs
      rescue => err
        # @result = nil
        $stderr.debugPuts(__FILE__, __method__, "ERROR", "ERROR: #{err} for doc:\n\n#{doc.inspect}\n\nError trace:\n\n#{err.backtrace.join("\n")}\n\n")
      end
      # At the end, we return @result as our new nested tabbed document (converted from KbDoc)
      return @result
    end

    # @param [BRL::Genboree::KB::KbDoc,Hash] subDoc Current sub document.
    # @param [String] nesting current nesting
    # @param [String] previousPath the previous path (used for updating nesting accurately)
    # @retur
    def visitSubDoc(subDoc, propStack, opts)
      if(subDoc)
        path = propStack.join(".")
        propDef = @modelsHelper.findPropDef(path, @model)
        # Get keys in some sensible order
        subDocKeys = getSubDocKeys(subDoc, propDef, propStack, opts)
        #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "Examining: #{propStack.join('.').inspect}\n        subDoc keys: #{subDoc.keys.inspect} ; subDocKeys: #{subDocKeys.inspect} ")

        #$stderr.puts "SUB-PROPS: #{subDocKeys.inspect}"

        # We traverse each of the keys gathered above for our sub document - each is a sub property of that document!
        subDocKeys.each { |subProp|
          #$stderr.puts "        SUB-PROP: #{subProp.inspect}"
          # Skip sub property if it's a Mongo ID (messes up bulkUpload in AbstractHelper)
          if(subProp == '_id')
            next
          elsif(!subDoc[subProp]) # Then this property is not in doc at all
            next
          else # Key is present and there is some value object ; no assumptions about which fields of value object are available
            currPropStack = (propStack + [subProp])
            currPath = currPropStack.join('.')
            # We update the nesting for the sub property (note that, for root property, nesting = nil)
            #$stderr.puts "        SUB-DOC: #{currPropStack.inspect}"
            subPropDef = @modelsHelper.findPropDef(currPath, @model)
            # Entering subdoc (sub-props are keys here), emit any lead-in tags/borders/lines etc
            chunk = enterSubDoc(subDoc, subPropDef, currPropStack, opts)
            emit(chunk)
            # We grab the value object associated with the current sub property
            valObj = subDoc[subProp]
            # Get actual value to render. Note:
            # * We get FULL list of sub-props from model
            # * But some may not be in doc ; or doc may have sub-prop with null value (for nullable) and then be
            #   correctly missing here if it is a leaf with just {value:null}.
            # * renderValue() is called on ALL possible sub-props, with nil value if sub-prop not present or with null value
            #   and it decides what to do.
            val = (valObj ? valObj['value'] : nil)
            valStr = renderValue(val, subPropDef, currPropStack, opts)
            emit(valStr)
            # Now, we've created the result string for the current sub property (with proper nesting) and added it to our @result array.
            # Next, we need to try to visit its sub-props / sub-items, recursively, using our visit methods.
            if(valObj)
              if(valObj.key?('properties'))
                visitSubDoc(valObj['properties'], currPropStack, opts)
              elsif(valObj.key?('items'))
                visitSubItems(valObj['items'], currPropStack, opts)
              end
            end
            # Leaving subdoc after completely recursively visiting ; emit any terminal tags/borders/lines/etc
            chunk = exitSubDoc(subDoc, subPropDef, currPropStack, opts)
            emit(chunk)
          end
        }
        # At the end of our "visit", we return @result with new, additional elements consisting of tabbed lines (property / value pairs).
      end
      return @result
    end

    def visitSubItems(subItems, propStack, opts)
      if(subItems)
        path = propStack.join(".")
        propDef = @modelsHelper.findPropDef(path, @model)
        #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "Items for: #{propStack.join('.')} ; (#{subItems.size} items to visit ; domain: #{propDef['domain'].inspect})")
        # Entering render of list of items/subdocs, emit any initial tags/xml/html/etc
        chunk = enterItems(subItems, propDef, propStack, opts)
        emit(chunk)
        # Visit each subdoc in the list. Item definition same for each item so can do just once
        itemPropDef = propDef['items'].first # Only one item in the list...the def of the subdocs that go in the lsit
        itemPropName =  itemPropDef['name']
        itemPropStack = (propStack + [itemPropName])
        itemPath = itemPropStack.join('.')
        subItems.each_index { |ii|
          item = subItems[ii]
          #$stderr.puts "        SUB-ITEM: #{(ii+1).inspect} ==> #{itemPropName.inspect} ; item keys: #{item.keys.inspect}"
          # Starting to render subdoc as an item in an item list...anything special to start the item?
          chunk = enterItem(item, itemPropDef, itemPropStack, opts)
          emit(chunk)
          # We grab the value object associated with the current sub property
          valObj = item[itemPropName]
          # Get actual value to render. Note:
          # * We get FULL list of sub-props from model
          # * But some may not be in doc ; or doc may have sub-prop with null value (for nullable) and then be
          #   correctly missing here if it is a leaf with just {value:null}.
          # * renderValue() is called on ALL possible sub-props, with nil value if sub-prop not present or with null value
          #   and it decides what to do.
          val = (valObj ? valObj['value'] : nil)
          valStr = renderValue(val, itemPropDef, itemPropStack, opts)
          emit(valStr)
          # Render subdoc below this item value (if any) ; regardless will never have a sub-items list; root props must have properties only below them
          if(valObj)
            if(valObj.key?('properties'))
              visitSubDoc(valObj['properties'], itemPropStack, opts)
            end
          end
          # We grab the value object a
          chunk = exitItem(item, itemPropDef, itemPropStack, opts)
          emit(chunk)
        }
        # Done render of list of items/subdocs, emit any terminal tags/xml/html/etc
        chunk = exitItems(subItems, propDef, propStack, opts)
        emit(chunk)
      end
      return @result
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
    # HELPERS - generally do not override parent methods
    # ------------------------------------------------------------------

    def init()
      # @errors will contain any errors we come across as we convert our document
      @errors = {}
      # @result will contain the final result (KbDoc in string form)
      @result = []
      @docValid = false
      # Finally, since we're done initializing our producer, we set @initialized to be true.
      @initialized = true
    end

    # Emit the chunck by yielding or by accumulating. Commonly needed as visit properties.
    # @param [String,nil] chunk The chunk string to emit (will have internal newlines most likely) or nil if this event told to emit nothing
    # @return none
    def emit(chunk)
      if(chunk)
        # If produce() is given a block, then we enter the first branch below
        if(@emissionCallback)
          @emissionCallback.call(chunk)
        else
          @result << chunk
        end
      end
      return
    end

    def getSubDocKeys(subDoc, propDef, propStack, opts)
      #$stderr.puts "KEYS FOR: #{propStack.inspect}"
      if(propStack.size <= 0) # then root ; @model is the prop def and only 1 key
        retVal = @model['name']
      else # not root, need to look in 'properties' for keys
        if(propDef and propDef['properties'])
          retVal = propDef['properties'].reduce([]) { |keys, subPropDef| keys << subPropDef['name'] }
        else # no properties, could be leaf or something
          retVal = []
        end
      end
      return retVal
    end
  end
end ; end ; end ; end # module BRL ; module Genboree ; module KB ; module Converters
