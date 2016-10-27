require 'fileutils'
require 'erubis'
require 'brl/util/util'
# Ensure these are done before attempting activesupport's core_ext stuff
require 'brl/activeSupport/activeSupport'
require 'brl/activeSupport/customCoreExt'
# Other brl stuff:
require 'brl/extensions/bson'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/kb/kbDoc'
require 'brl/genboree/kb/helpers/modelsHelper'
require 'brl/genboree/kb/validators/modelValidator'
require 'brl/genboree/kb/validators/docValidator'
require 'brl/genboree/kb/producers/fullPathTabbedDocProducer'


module BRL ; module Genboree ; module KB ; module Producers
  class AbstractTemplateProducer
    module ContextExtensions
      # Code here will be evaluated within an Erubis::Context instance. This Context object is Hash-like, and
      # exposed its Symbol=>Values will be mapped to instance variables to the template and the template will
      # also have access to any Erubis::Context methods. THEREFORE, we can mix some specially little
      # convenience methods into the Erubis::Context object we're using--see makeContext() and employ those
      # conveniences in the template. Basically little aliases if the variableized paths are annoying you, etc.

      # @return [String] The name of the root property of the KbDoc.
      def rt()
        @__kbDoc.getRootProp()
      end

      # Get the value of property indicated by the path.
      # @param [String] path The dot-delimited property path of the property you want the value for.
      # @param [Hash<Symbol,Object>] opts Optional. Override certain default behaviors.
      # @option opts [Object] :default (nil) What to return if the property is not present.
      # @option opts [String] :nl What to replace any two-char newline characters in the text with. Defaults to
      #   whatever  the :twoCharNewline option is in the AbstractTemplateProducer obejct or to '<br>' if that
      #   wasn't configured when setting up the AbstractTemplateProducer.
      # @return [String,nil] The value of the indicated property or the :default value (which is nil if you don't override it)
      def pv(path, opts={:default=>nil, :nl=>(@__opts[:twoCharNewline] or '<br>')})
        retVal = ( @__producer.pathValueMap[path] or opts[:default]  )
        if(opts[:nl])
          # Newlines in JSON strings will be 2-char sequence \\n not preceded by a \\.
          retVal = retVal.to_s.gsub(/([^\\])(?:\\n)+/) { |xx| "#{$1}#{opts[:nl]}" }
        end
        return retVal # Could use @__kbDoc.getPropVal() as well, but it will be slower b/c more work.
      end

      # Get Prop Name (last item in path). Optionally as some id-safe string.
      # @param [String] path The dot-delimited property path of the property you want leaf property name for.
      # @param [Hash<Symbol,Object>] opts Optional. Override certain default behaviors.
      # @option opts [boolean] :idSafe (false) Return the property name as a variable-ized/id-safe string, suitable for
      #   CSS class names, variable name, etc.
      # @return [String] The property name.
      def pn(path, opts={:idSafe=>false})
        retVal = path.to_s.split(/\./).last
        if(opts[:idSafe])
          retVal = retVal.variableize
        end
        return retVal
      end

      # Get the items under the items-list property.
      # @param [String] path The dot-delimited property path of the item-list property whose items you want.
      # @return [Array<KbDoc>] The items under the property, if any.
      def items(path)
        @__kbDoc.getPropItems(path)
      end

      # Does the property exist in the doc, and [by default] have a non-empty/non-whitespace-only value?
      # @param [String] path The dot-delimited property path you want to test the presence of.
      # @param [Hash<Symbol,Object>] opts Optional. Override certain default behaviors.
      # @option opts [boolean] :allowBlankVal (false) To make this method return true for properties that are
      #   present in the doc, even if their values are empty or all-whitespace, set this option to true.
      # @return [boolean] Whether the property exists in the doc or not.
      def exists?(path, opts={:allowBlankVal=>false})
        val = @__producer.pathValueMap[path]
        return (val and (opts[:allowBlankVal] or val.to_s =~ /\S/))
      end
      alias_method :'e?', :'exists?'

      # Count the number of items under the items-list property.
      # @param [String] path The dot-delimited property path whose items you want to count.
      # @return [Fixnum] The number of items in the items-list property. If path doesn't indicate an items-list
      #   property (a) you probably made a mistake and need to consult your model & template, (b) this will of course
      #   return 0.
      def count(path)
        items = @__kbDoc.getPropItems(path)
        return (items ? items.size : 0)
      end
      alias_method :num, :count

      # Does the code block evaluate to true for an item under the items-list property?
      # @param [String] path The dot-delimited property path whose items you want check.
      # @yieldparam [BRL::Genboree::KB::KbDoc] item The item KbDoc object is yielded to the code block for evaluation;
      #   code block assumed to return true/false value just like ruby's any? or all? methods.
      # @return [boolean] Does the code block evaluate to true for any item?
      def any(path, &blk)
        items = @__kbDoc.getPropItems(path)
        if(items)
          retVal = items.any? { |itm|
            blk.call( BRL::Genboree::KB::KbDoc.new(itm) )
          }
        else
          retVal = false
        end
        return retVal
      end

      # Render each item within an item list indicated by propPath using the indicated template.
      # By default, no separator string will be placed between each item...but you can tell it to add one.
      # @param [String] propPath The dot-delimited property path whose items are to be rendered using @template@.
      # @param [Symbol, String] template The template to use to render the item.
      # @param [String] sep Optional. The string to place after each item. For example, a comma or maybe '<br>' or similar.
      # @param [Hash<Symbol,Object>] opts Optional. Override certain default behaviors.
      # @option opts [boolean] :supressNewlineAfterItem (false) By default, a newline character will be output after
      #   each item is rendered. For most outputs like XML/HTML this has no real effect on the display and can make the
      #   output easier to read. But in some cases, this newline is bad. Set this option to true to turn off the newline.
      # @return [String] The rendered output.
      def render_each(propPath, template, sep='', opts={})
        @__producer.render_each(propPath, template, sep, opts)
      end

      # Render a sub-doc/sub-tree--i.e. a non-item-list portion of the document--using a dedicated template.
      # For keeping templates simple and clear. Not really needed. And doing it too much means too many templates
      # to keep track of. So some balance/common sense of when to employ this for maintenance/clarity is best.
      # @param [String] propPath The dot-delimited property path which to redner using the template. This property will
      #   be the root of the KbDoc presented to the template.
      # @param [Symbol, String] template The template to use to render the sub-doc.
      # @param [Hash<Symbol,Object>] opts Optional. Override certain default behaviors.
      # @return [String] The rendered output.
      def subRender(propPath, template, opts={})
        @__producer.subRender(propPath, template, opts)
      end

      # Get or set a global option in the AbstractTemplateProducer object.
      # @note Most useful as a getter, so check for some global option, even a custom one set when AbstractTemplateProducer
      #   was instantiated and configured.
      # @note Danger: if used to set/change a global option, it is persistent from that point forward, so be careful if abusing it for what
      #   should be a temporary setting of a global option.
      # @param [Symbol] sym The option to set, always as a Symbol.
      # @param [Object] args Optional. Dangerous. The value to set the option to; if more than one is provided,
      #   the option value will be an Array with all the args.
      # @return [Object] The value of the option.
      def opt(sym, *args)
        if(args and args.size >= 1) # setting opt
          # If just one (as intended!), it's the value for the opt so extract it; else if
          #   more than one (ugh), save as array of all values.
          retVal = @__opts[sym] = (args.size == 1 ? args.first : args)
        else # getting opt
          retVal = @__opts[sym]
        end
        return retVal
      end

      # Get a property definition object from the model.
      # @param [String] path The dot-delimited property path for the property whose definition object you want to get.
      # @return [Hash] The property definition object for the property.
      def propDef(path)
        @__producer.propDef(path)
      end
    end # module ContextExtensions

    attr_accessor :genbConf, :templateDir
    attr_accessor :kbDoc, :templateFile, :opts
    attr_accessor :skipValidation # ONLY if you KNOW doc is valid vs its model. For example if dynamically retrieved model and doc at same time.
    attr_reader :templater
    attr_reader :modelValidator, :modelHelper, :pathValueTable, :pathValueMap, :variableValueMap

    def initialize(model, kbDoc, opts={})
      @templater = @templateFile = @templateDir = @genbConf = nil
      @modelValidator = BRL::Genboree::KB::Validators::ModelValidator.new()
      @modelValidator.relaxedRootValidation = (opts.key?(:relaxedRootValidation) ? opts[:relaxedRootValidation] : true)
      raise ArgumentError, "ERROR: model provided fails validation. Not a proper, compliant model. Errors:\n#{@modelValidator.validationErrors.join("\n")}\n\n" unless(@modelValidator.validateModel(model))
      @modelHelper = BRL::Genboree::KB::Helpers::ModelsHelper.new(@model)
      @opts = opts
      @model = model
      @kbDoc = kbDoc
    end

    def findTemplateDir(opts=@opts)
      # Where are templates?
      templateDir = opts[:templateDir]
      if(templateDir.nil? or templateDir.blank?) # No template dir to use as override, get "official" one
        @genbConf = BRL::Genboree::GenboreeConfig.load()
        @templatedir = @genbConf.kbProducerTemplateDir
      else
        @templateDir = templateDir
      end
      raise "ERROR: Template dir #{@templateDir.inspect} doesn't exist, isn't readable, or isn't a directory." unless(File.readable?(@templateDir) and File.directory?(@templateDir))
      return @templateDir
    end

    def loadTemplate(template, opts=@opts)
      @templateDir = findTemplateDir(opts)
      if(template.is_a?(Symbol)) # Turn into template file name
        templateFileName = "#{template}.tpl"
      else
        raise ArgumentError, "ERROR: template argument must be either a Symbol indicating a template within your template-dir. It cannot be a #{template.class}."
      end
      templatePath = "#{@templateDir}/#{templateFileName}"
      raise "ERROR: The template file #{templateFileName.inspect} doesn't exist within the template directory #{@templateDir.inspect}." unless(File.readable?(templatePath) and File.file?(templatePath))
      return File.read(templatePath)
    end

    def render(template, opts=@opts)
      # Don't raise error when bad path for doc, just return nil for any get*() operations
      @kbDoc.nilGetOnPathError = true
      if(template.is_a?(Symbol)) # Then Symbol indicates a template filename within @templateDir
        # Load template and get a template-renderer for it
        templateContent = loadTemplate(template, opts)
      elsif(template.is_a?(String)) # The it IS the template content to use
        templateContent = unescapeErbTags(template)
      else
        raise ArgumentError, "ERROR: template argument must be either a Symbol indicating a template within your template-dir or a String which is the template content itself. It cannot be a #{template.class}."
      end
      @templater = Erubis::FastEruby.new( templateContent )
      # Initialize needed data structures from info extracted from doc
      initFromDoc(opts)
      # Render template using doc info
      contextHash = makeContext()
      #$stderr.puts "contextHash:\n\n#{contextHash.inspect}\n\n"
      retVal = @templater.evaluate(contextHash)
      return retVal
    end

    def unescapeErbTags(string)
      retVal = string.gsub(/<!(!*)%/, '<\1%').gsub(/%!(!*)>/, '%\1>')
      return retVal
    end

    def makeContext()
      context = Erubis::Context.new( @variableValueMap.deep_clone )
      context[:__producer] = self
      context[:__kbDoc] = @kbDoc
      context[:__opts] = @opts
      context.extend(ContextExtensions)
      return context
    end

    def propDef(propPath, model=@model)
      @modelHelper.findPropDef(propPath, model)
    end

    def subRender(propPath, template, opts={})
      # Get propDef of sub-doc under propPath
      subModel = @modelHelper.findPropDef(propPath, @model)
      # Get sub-doc itself
      subDoc = @kbDoc.getSubDoc(propPath)
      # Need to have a sub-doc at that path and the value object cannot be nil for it
      if(subDoc)
        # Create a templater object
        subOpts = @opts.deep_clone
        subOpts[:relaxedRootValidation] = true # Since new doc will actually be sub-doc and thus root-validations are not all appropriate
        subTemplater = AbstractTemplateProducer.new(subModel, subDoc, subOpts)
        # We have validated whole doc at outermost level, and sub-docs extracts are likely not valid as standalone anyway.
        subTemplater.skipValidation = true
        # Render the subDoc using the template
        retVal = subTemplater.render(template, subOpts)
      else # nothing at that prop path == nothing to render!
        retVal = ""
        #$stderr.debugPuts(__FILE__, __method__, 'DEBUG', "CAN'T RENDER NOTHING! subDoc for #{propPath.inspect} is #{subDoc.inspect} and can't be rendered with #{template.inspect}")
      end
      return retVal
    end

    def render_each(propPath, template, sep='', opts={})
      #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "START => Started render each item found at #{propPath.inspect}. Using template: #{template.is_a?(String) ? "\n    #{template[0,48].inspect}#{'...' if(template.size > 48)}" : template.inspect}")
      retVal = ''
      itemSep = ( opts[:supressNewlineAfterItem] ? ' ' : "\n" )
      # Get propDef of sub-doc under propPath
      subModel = @modelHelper.findPropDef(propPath, @model)
      if(subModel)
        if(subModel.key?('properties'))
          raise ArgumentError, "ERROR: cannot use render_each with non-items list properties; #{propPath.inspect} has sub-props, not sub-items."
        elsif(subModel.key?('items')) # then there are actual items present
          # Get sub-doc containing the items
          subDoc = @kbDoc.getSubDoc(propPath)
          if(subDoc)
            # The items list
            propName = subDoc.getRootProp
            items = subDoc.getPropItems(propName)
            if(items)
              itemTemplater = nil # will make it using first item only
              items.each_index { |ii|
                item = items[ii]
                itemDoc = BRL::Genboree::KB::KbDoc.new(item)
                # Make itemTemplater using item info if we haven't already
                unless(itemTemplater)
                  itemOpts = @opts.deep_clone
                  itemOpts.merge!(opts)
                  itemOpts[:relaxedRootValidation] = true # Since new doc will actually be sub-doc and thus root-validations are not all appropriate
                  itemRoot = itemDoc.getRootProp()
                  itemModel = @modelHelper.findPropDef("#{propName}.#{itemRoot}", subModel)
                  itemTemplater = AbstractTemplateProducer.new(itemModel, itemDoc, itemOpts)
                  # We have validated whole doc at outermost level, and sub-docs extracts are likely not valid as standalone anyway.
                  itemTemplater.skipValidation = true
                end
                # Regardless, use itemTemplater to render item
                itemTemplater.kbDoc = itemDoc # ensure we're not still on the initial one
                renderedItem = itemTemplater.render(template)
                isLast = (ii >= (items.size - 1))
                retVal = "#{retVal}#{itemSep}#{renderedItem}#{sep unless(isLast)}" # interpolation is apparently faster than string growth.
              }
            end
          else # No such subdoc
            retVal = ''
          end
        else # don't seem to be items and not one that has 'properties' ; nothing to render
          retVal = ''
        end
      else # Can't find subModel, no such path probably
        errMsg = "The path #{propPath.inspect} is not valid within the model. Cannot get a property-definition for the property at that path."
        $stderr.debugPuts(__FILE__, __method__, 'ERROR', errMsg)
        retVal = "*** ERROR: #{errMsg} ***"
      end
      #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "END => Done render each item found at #{propPath.inspect}. Using template: #{template.is_a?(String) ? "\n    #{template[0,72].inspect}#{'...' if(template.size > 72)}" : template.inspect}\n#{'-'*50}")
      return retVal.strip
    end

    def initFromDoc(opts=@opts)
      fullPathProducer = BRL::Genboree::KB::Producers::FullPathTabbedDocProducer.new(@model)
      fullPathProducer.relaxedRootValidation = opts[:relaxedRootValidation]
      # Validate doc
      if(@skipValidation)
        docValid = true
      else
        begin
          docValid = fullPathProducer.validateDoc(@kbDoc)
        rescue => err
          #$stderr.debugPuts(__FILE__, __method__, 'DEBUG - INTERCEPTION', "Validation threw error:\n  Error class: #{err.class}\n  Error message: #{err.message}\nThe opts are:\n    #{opts.inspect}\nThe kbDoc is:\n\n#{kbDoc.inspect}\n\n")
          docValid = false
        end
      end

      if(docValid)
        # Get full path version of doc
        fullPathLines = fullPathProducer.produce(@kbDoc)
        # Reduce lines to hash of path => value
        @pathValueTable = fullPathLines.map { |line| line.split("\t").map { |cell| cell.strip } }
        # Variableize keys.
        @variableValueMap = {}
        @pathValueMap = {}
        @pathValueTable.each { |rec|
          path, value = *rec
          @pathValueMap[path] = value
          varSym = makeVariableSym(path, opts)
          if(@opts[:twoCharNewline])
            # Newlines in JSON strings will be 2-char sequence \\n not preceded by a \\.
            value = value.to_s.gsub(/([^\\])(?:\\n)+/) { |xx| "#{$1}#{@opts[:twoCharNewline]}" }
          end
          @variableValueMap[varSym] = value
        }
      else
        raise ArgumentError, "ERROR: the doc provided is not valid vs its model. Validation errors:\n - #{fullPathProducer ? fullPathProducer.validator.validationErrors.join("\n -") : '[not available; bad producer class]'}"
      end

      return @variableValueMap
    end

    def makeVariableSym(path, opts=@opts)
      pathAliases = opts[:aliases]
      # Convert doc-paths, which can have .[] index placeholders, into model paths, which don't
      modelPath = BRL::Genboree::KB::KbDoc.docPath2ModelPath(path)
      # If provided specific path->variableized aliases (overrided for auto-gen variableized names), use them
      if(pathAliases and pathAliases[modelPath])
        varName = pathAliases[modelPath].to_sym
      else # auto-generate variableized names
        varName = modelPath.variableize()
      end
      return varName.to_sym
    end
  end # class AbstractRhtmlTemplateProducer
end ; end ; end ; end  # module BRL ; module Genboree ; module KB ; module Producers
