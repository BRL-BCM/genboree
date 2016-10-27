require 'brl/util/util'
require 'brl/extensions/bson'
require 'brl/genboree/kb/producers/abstractProducer'

module BRL ; module Genboree ; module KB ; module Producers
  class SimpleTextileProducer < AbstractProducer

    TAB_STR = '  '

    TXTL_CHR_REPLACE = {
      :parsedEntity => {
        '*' => '&#42;',
        '_' => '&#96;',
        '+' => '&#43;',
        '-' => '&#45;',
        '~' => '&#126;',
        '^' => '&#94;',
        '%' => '&#37;',
        '@' => '&#64;'
      }
    }

    MODEL_INFO_CLASSES = [ :index, :required, :unique, :fixed, :category, :ident, :facet ]

    # CONSTRUCTOR.
    # @param [Hash,BRL::Genboree::KB::KbDoc] model The model @Hash@ or full @KbDoc@ wrapped model for the
    #   doc to be rendered.
    # @param [Proc,nil] emissionCallback If want to be be *streamed* the lines/chunks as they are generated,
    #   which is good for saving RAM or dealing with massive inputs/outputs, pass in a {Proc} callback that takes
    #   one argument, a line/chunk being emitted. If @nil@, all chunks/lines will be accumulated in an @Array@
    #   and availble from @result.
    # @param [Array] args To aid subclass design & usage while keeping a uniform interface any specific arguments can be
    #   passed as well.
    def initialize(model, emissionCallback=nil, *args)
      super(model, emissionCallback, *args)
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
      opts[:nestingChrs] = []
      return nil
    end

    # Generate terminal 'footer' string for the doc. Close XML/HTML tags, add comments, newlines, etc.
    # @param [BRL::Genboree::KB::KbDoc] doc Document being dumped in some other format.
    # @param [Hash] opts Additional options/info Hash, possibly subclass-specific, changes to hash
    #   contents will propagate forward which is useful for accumulating/decummulating array stacks and such.
    # @return [String] The footer string.
    def exitDoc(doc, opts)
      opts.delete(:nestingChrs)
      return nil
    end

    # Generate any opening xml/html tags etc for starting a subDoc. Generally, not for rendering the value display
    #  (@see #renderValue, #renderItem). Keep in mind that the subDoc may have a deep doc tree below it; we're doing DFS
    #   and pseudo-events via these enter/exit methods.
    # @param [Hash] doc The subdoc we're beging to recursively render.
    # @param [Hash] propDef The property definition Hash for this propety, from the model
    # @param [Array] propStack Current stack of properties, which starts at the root property down to the parent of @doc@
    # @param [Hash] opts Additional options/info Hash, possibly subclass-specific, changes to hash
    #   contents will propagate forward which is useful for accumulating/decummulating array stacks and such.
    # @return [String] The begin-subdoc emission string.
    def enterSubDoc(doc, propDef, propStack, opts)
      retVal = nil
      origNest = opts[:nestingChrs].dup
      if(propStack.size > 1) # then is not root property
        if(propDef)
          opts[:nestingChrs] << '*'
        end
        retVal = "#{opts[:nestingChrs].join()} "
      end
      #$stderr.puts "#{'  '*propStack.size}IN-DOC : #{propStack.join('.')} (prop name: #{(propDef ? propDef['name'].inspect : 'ROOT')}) ; #{origNest.inspect} => #{opts[:nestingChrs].inspect} ; retVal: #{retVal.inspect}"
      return retVal
    end

    # Generate any closing xml/html tags, terminal newlines, etc for closing a fully-visited subDoc. We're doing DFS and pseudo-events via these enter/exit methods.
    # @param (see #enterSubDoc)
    # @return [String] The end-subdoc emission string.
    def exitSubDoc(doc, propDef, propStack, opts)
      retVal = nil
      origNest = opts[:nestingChrs].dup
      opts[:nestingChrs].pop
      #$stderr.puts "#{'  '*propStack.size}OUT-DOC: #{propStack.join('.')} (prop name: #{(propDef ? propDef['name'].inspect : 'ROOT')}) ; #{origNest.inspect} => #{opts[:nestingChrs].inspect} ; retVal: #{retVal.inspect}"
      return retVal
    end

    # Generate any opening xml/html tags etc for starting an items list (e.g. open a <ol> or something). Other methods will be called as
    #   each item is visited. Keep in mind that the item may have a deep doc tree below it; we're doing
    #   DFS and pseudo-events via these enter/exit methods.
    # @param [Array<Hash>] items The array of items about to be DFS-visited.
    # @param [Hash] propDef The property definition Hash for this propety, from the model
    # @param [Array] propStack Current stack of properties, which starts at the root property down to the parent of @doc@
    # @param [Hash] opts Additional options/info Hash, possibly subclass-specific, changes to hash
    #   contents will propagate forward which is useful for accumulating/decummulating array stacks and such.
    # @return [String] The begin-items-list emission string
    def enterItems(items, propDef, propStack, opts)
      retVal = nil
      origNest = opts[:nestingChrs].dup
      #opts[:nestingChrs] << '#'
      #retVal = "#{opts[:nestingChrs].join()} "
      #$stderr.puts "#{'  '*propStack.size}IN-ITEMS : #{propStack.join('.')} (prop name: #{(propDef ? propDef['name'].inspect : 'ROOT')}) ; #{origNest.inspect} => #{opts[:nestingChrs].inspect} ; retVal: #{retVal.inspect}"
      return retVal
    end

    # Generate any closing xml/html tags, terminal newlines, etc for starting an items list (e.g. open a </ol> or something).
    #   We're doing DFS and pseudo-events via these enter/exit methods.
    # @param (see #enterItems)
    # @return [String] The end-items-list emission string
    def exitItems(items, propDef, propStack, opts)
      retVal = nil
      origNest = opts[:nestingChrs].dup
      #opts[:nestingChrs].pop
      #retVal = "#{opts[:nestingChrs].join()} "
      #$stderr.puts "#{'  '*propStack.size}OUT-ITEMS: #{propStack.join('.')} (prop name: #{(propDef ? propDef['name'].inspect : 'ROOT')}) ; #{origNest.inspect} => #{opts[:nestingChrs].inspect} ; retVal: #{retVal.inspect}"
      return retVal
    end

    # Generate the opening xml/html tags etc for a subDoc about to be rendered within the context of an items list
    #   (e.g. <li>, </div> or something). Other methods will be called to render the actual subDoc value (see #renderValue) and the
    #   subDoc will be recursively visited to render what is below it.
    # @param (@see #renderValue)
    # @return [String] The begin-item emission string.
    def enterItem(doc, propDef, propStack, opts)
      retVal = nil
      origNest = opts[:nestingChrs].dup
      opts[:nestingChrs] << '#'
      retVal = "#{opts[:nestingChrs].join()} "
      #$stderr.puts "#{'  '*propStack.size}IN-ITEM : #{propStack.join('.')} (prop name: #{(propDef ? propDef['name'].inspect : 'ROOT')}) ; #{origNest.inspect} => #{opts[:nestingChrs].inspect} ; retVal: #{retVal.inspect}"
      return retVal
    end

    # Generate the closing xml/html tags etc for a subDoc about to be rendered within the context of an items list
    #   (e.g. </li>, </div> or something). Other methods will be called to render the actual subDoc value (see #renderValue) and the
    #   subDoc will be recursively visited to render what is below it.
    # @param (@see #renderValue)
    # @return [String] The end-item emission string.
    def exitItem(doc, propDef, propStack, opts)
      retVal = nil
      origNest = opts[:nestingChrs].dup
      opts[:nestingChrs].pop
      #$stderr.puts "#{'  '*propStack.size}OUT-ITEM: #{propStack.join('.')} (prop name: #{(propDef ? propDef['name'].inspect : 'ROOT')}) ; #{origNest.inspect} => #{opts[:nestingChrs].inspect} ; retVal: #{retVal.inspect}"
      return retVal
    end

    # Generate the xml/thml tags etc for rendering the value of a subDoc. Subdoc may be a simple child property
    #   or an item in an item list. Keep in mind that the subDoc may have a deep doc tree below it; we're doing
    #   DFS and pseudo-events via these enter/exit methods.
    # @param [Object] value The value from the property's value object.
    # @param [Hash] propDef The property definition Hash for this propety, from the model
    # @param [Array] propStack Current stack of properties, which starts at the root property down to the parent of @doc@
    # @param [Hash] opts Additional options/info Hash, possibly subclass-specific, changes to hash
    #   contents will propagate forward which is useful for accumulating/decummulating array stacks and such.
    # @return [String] The value emission string.
    def renderValue(value, propDef, propStack, opts)
      #$stderr.puts "#{'   '*propStack.size}RENDER VAL: #{value.inspect} ; prop name: #{(propDef ? propDef['name'].inspect : 'ROOT')} ; path: #{propStack.join('.')}; propDef keys: #{propDef.keys.inspect}"
      # If value is nil, either it is missing in doc completely or has null value.
      # Here, we don't render such nil values IFF node is a leaf AND value is nil
      if(value.nil?)
        if(propDef.key?('properties') or propDef.key?('items')) # then has subprops or subitems
          retVal = makePropNameValue(propDef['name'], value, propDef, propStack, opts)
        else
          $stderr.debugPuts(__FILE__, __method__, "DEBUG", "prop: #{propStack.join('.')}")
          retVal = "\n"
        end
      else # have non-nil value to display
        retVal = makePropNameValue(propDef['name'], value, propDef, propStack, opts)
      end
      return retVal
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
      retVal = super(opts)
      if(retVal)
        # Check :classizeWithModelInfo sanity w.r.t. other opts
        if(opts.key?(:classizeWithModelInfo) and opts[:classizeWithModelInfo])
          # While can have just :classizeWithModelInfo (implies :classize), can't have it with explicit :classize of false or nil
          if(opts.key?(:classize))
            if(opts[:classize])
              opts[:classize] = true # normalize true value
            else
              retVal = false # defensive
              raise ArgumentError, "ERROR: Bad opts hash values. Can't have :classizeWithModelInfo=>#{opts[:classizeWithModelInfo].inspect} with explicit :classize=>#{opts[:classize].inspect} which contradicts it. If using :classizeWithModelInfo mode, don't need to set anything for :classize because it is already *implied*."
            end
          else
            opts[:classize] = true # it's implied
          end
          # Can override which model fields lend classes to output, but has to be at least one
          if(opts.key?(:modelClasses))
            modelClasses = opts[:modelClasses]
            if(!modelClasses.is_a?(Array) or modelClasses.size < 1)
              raise ArgumentError, "ERROR: Bad opts hash values. Opts value for :modelClasses must be a non-empty Array."
            elsif(  !modelClasses.all?{ |xx| xx.is_a?(Symbol)} or
                    !modelClasses.all?{ |xx| MODEL_INFO_CLASSES.any?{ |yy| xx == yy } })
              raise ArgumentError, "ERROR: Bat opts hash values. The Symbols in the :modelClasses Array MUST be only some of these: #{MODEL_INFO_CLASSES.inspect}"
            end
          else
            opts[:modelClasses] = MODEL_INFO_CLASSES.dup
          end
        end
      end
      return retVal
    end

    # ------------------------------------------------------------------
    # HELPERS - generally do not override parent methods
    # ------------------------------------------------------------------

    def getClasses(propName, value, propDef, propStack, opts)
      classes = []
      modelClasses = opts[:modelClasses]
      #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "modelClasses: #{modelClasses.inspect}")
      if(modelClasses)
        classes << 'index' if(modelClasses.include?(:index) and propDef['index'])
        classes << 'required' if(modelClasses.include?(:required) and propDef['required'])
        classes << 'unique' if(modelClasses.include?(:unique) and propDef['unique'])
        classes << 'fixed' if(modelClasses.include?(:fixed) and propDef['fixed'])
        classes << 'category' if(modelClasses.include?(:category) and propDef['category'])
        classes << 'ident' if(modelClasses.include?(:ident) and propDef['identifier'])
        classes << 'facet' if(modelClasses.include?(:facet) and propDef['Is Facet?'])
      end
      # Add the domain 'type' string
      domainRec = @modelValidator.getDomainRec(propDef['domain'])
      classes << domainRec[:type]
      return classes
    end

    def makePropNameValue(propName, value, propDef, propStack, opts)
      depth = propStack.size - 1
      # Prop name first, with any class wrapper if requested
      nameStr = "#{propName}:"
      if(opts[:classize] or opts[:classizeWithModelInfo])
        classes = ( ["propName", "depth#{depth}"] + getClasses(propName, value, propDef, propStack, opts) )
        nameStr = "%(#{classes.join(' ')})#{nameStr}%"
      end
      # Add prop value, with any class wrapper if requested
      if(propDef['domain'] == '[valueless]')
        valStr = ""
      else
        if(value.nil?)
          valStr = (opts[:noValue] or '[no value]')
        else # have non-nil value to display
          valStr = displayable(value, propDef, propStack, opts)
        end
        # Classize value if requested
        valStr = "%(propVal depth#{depth})#{valStr}%" if(opts[:classize])
      end
      retVal = "#{nameStr} #{valStr}\n"
      unless(opts[:classize])
        # not class-izing ; use h1 for root property since classes can't be used to style or anything
        retVal = "h1. #{retVal}\n" if(depth == 0)
      end
      return retVal
    end

# Format textile according to domain. May be mutually exclusive with textileEscape, at least on raw value
bioportalTerm
bioportalTerms
date
domainedLabelUrl
enum
fileUrl
labelUrl
omim
pmid
timestamp
url

    def displayable(value, propDef, propStack, opts)
      mode = (opts[:blankLineMode] or :insertSpecialSpan)
      depth = propStack.size - 1
      retVal = textileEscape(value.to_s, opts)
      retVal.gsub!(/\r *\n/, "\n")  # dos
      retVal.gsub!(/\r/, "\n")    # old mac
      # No matter what we go down to 1 newline first.
      retVal.gsub!(/ *\n\n+ */, "\n") # multiple => 1
      retVal.strip!
      # Are we trying to get better control over paragraphs in lengthy text and avoid cases where markup breaks
      # due to even raw newline? Then replace newlines with special span that can be CSS'd
      if(mode == :insertSpecialSpan) # else is :makeOneNewLine implicitly (we start with that regardless)
        if(opts[:classize]) # need to interrupt current value wrapper span and then reopen for next paragraph
          numNewlines = retVal.count("\n")
          if(numNewlines > 0)
            retVal.gsub!(/\n/, "% %(blankLine)&nbsp;% %(propVal depth#{depth})")
            # Must close any new value span we opened. Because >0 newlines, we know there is at least 1...
            retVal << "%"
          end
        end
      end
      return retVal
    end

    def textileEscape(value, opts)
      retVal = value.dup
      mode = (opts[:textileEscMode] or :parsedEntity)
      if(mode == :parsedEntity)
        map = TXTL_CHR_REPLACE[mode]
        map.keys.each { |char|
          retVal.gsub!(/#{Regexp.escape(char)}/, map[char])
        }
      elsif(mode == :classedBold)
        map = TXTL_CHR_REPLACE[:parsedEntity] # Can reuse keys from parsedEntity's map
        map.keys.each { |char|
          retVal.gsub!(/(#{Regexp.escape(char)})/) { |char|
            "[\v(textileSpecial)#{char}\v]"
          }
        }
        retVal.gsub!(/\v/, '*')
      elsif(mode == :none)
        retVal = retVal
      else
        raise ArgumentError, "Unknown :textileEscMode mode in options: #{mode.inspect}"
      end
      return retVal
    end
  end
end ; end ; end ; end # module BRL ; module Genboree ; module KB ; module Converters
