require 'time'
require 'date'
require 'uri'
require 'sha1'
require 'json'
require 'memoist'
require 'brl/util/util'
require 'brl/extensions/units'
require 'brl/extensions/string'
require 'brl/genboree/kb/mongoKbDatabase'
require 'brl/genboree/kb/validators/modelValidator'

module BRL ; module Genboree ; module KB ; module Validators
  class DocValidator

    attr_accessor :docId
    attr_accessor :model
    attr_accessor :dataCollName
    attr_accessor :kbDatabase
    attr_accessor :modelValidator
    # @return [Hash{String, Array<String>] A Hash of property paths to array of validation error strings for that property.
    #   For top-level validation errors encountered prior to seeing the first property, the key will be empty String ('').
    attr_accessor :validationErrors
    # @return [Hash{String, Array<String>] A Hash of property paths to array of validation warning strings for that property.
    #   For top-level validation errors encountered prior to seeing the first property, the key will be empty String ('').
    attr_accessor :validationWarnings
    attr_accessor :validationMessages
    attr_accessor :lastIdKey
    attr_accessor :modelCache
    attr_accessor :disableCache
    # @return [Hash<String, Hash>] mapping a property path to a context Hash with information for the content generation framework
    #   the context Hash (from e.g. BRL::Genboree::KB::Validators::ModelValidator#validVsDomain) contains the following keys
    #   :result, :pathElems, :propDef, :domainRec, :parsedDomain, :scope
    attr_accessor :contentNeeded
    # @return [boolean] Generally, letting this be automatically set is sufficient, but you can override the default. If the validateDoc()
    #   run is in offline/stand-alone mode, then having missing content is ok since we aren't in contact with an actual KB & collection
    #   for this validation.
    attr_reader :missingContentOk
    # @return [Hash{String,Array}] A map of prop names (not full paths) to POSSIBLE parent property paths. Used to make suggestions
    #   for illegal properties that may in fact just be misplaced.
    attr_reader :parentSuggestions
    attr_accessor :uniqueProps
    # @return [boolean] Should validation skip uniqueness check for items lists as in the case of a first validation with an item list of autoID domain properties.  @false@ by default.
    attr_accessor :allowDupItems
    # @return [boolean] Should validation also cast/normalize values in the source doc? @false@ by default.
    attr_accessor :castValues
    # @return [boolean] Should validation also check whether each value needs casting/normalization prior to save, etc. @false@ by default
    #   This will also enabling the optional tracking of property paths in the doc that need casting/normalization.
    attr_accessor :needsCastCheck
    # @return [Array<String>] If @@needsCastCheck@ is @true@, this will have a list of property paths in the doc whose values need casting.
    #   By default this list is EMPTY and the @needsCastCheck@ is not done (to save unnecessary overhead)
    attr_accessor :needsCastingPropPaths
    # @return [boolean] Should we relax validation of the root property? Example: validating a sub-doc extracted from full KbDoc using KbDoc#getSubDoc
    #   against its model extracted from the model using ModelsHelper#findPropDef. In this case, the sub-doc root is almost certainly not going to
    #   meet many of the special criteria for doc roots.
    attr_accessor :relaxedRootValidation
    # @return [Fixnum] How many errors can we accumulate before stopping? By default, this limit is 50 but setting to nil will accumulate ALL
    #   errors (or until one that halts further validation is encountered). Having an uncapped limit (via nil) is NOT SMART, since it means that
    #   (a) validation time is also uncapped--possibly a disaster if trying to validate more than one doc or if blocking further request
    #   handling in a web worker; and (b) you do a disservice to the USER, for whom the report is too overwhelming, too large, and possibly
    #   contains similar errors over and over and over. This number is best small enough that the report is not soul-crushing, not long to
    #   generate, but while being large enough to represent many of the errors and not have the user having to repeat validation/submission
    #   over and over just to see all their various errors.
    attr_accessor :errorCountCap
    # @return [Fixnum] How many erroneous items will be examined/reported before pruning further examination of the item list?
    #   Default 5 (per items list) This option allows the validator to notice and report errors for some 'representative' items without
    #   having large items lists dominate the feedback with repetitive noise (since same errors likely seen over and over by each [or many]
    #   items in the list). Also it prevents items errors from contributing too much to the overall maximum error count and stopping document
    #   examination too early by hitting the cap. As with @errorCountCap, setting this to nil uncaps the limit; NOT SMART in most cases.
    attr_accessor :erroneousItemsCap
    # @return [Fixnum] How many suggestions to make for an illegal-but-possibly-misplaced property? Some very generic property names like
    #   'Name' or 'Notes' may be possible in MANY places in the model, so capping this is a good idea. Default is 3.
    attr_accessor :parentSuggestionCap
    # @return [String] When building per-property error messages, what text, if any, to put in front of each property path for which there
    #   are errors? Do include any space separating prefix from property path. By default this is 'ERRORS FOR PROPERTY ' as part
    #   of building a readable multi-line message string. Could set to '' to make more mininmalistic version output.
    attr_accessor :propPrefix
    # @return [String] When building per-property error messages, what text, if any, to put after each property path for which there are errors?
    #   Do include any newline if you want the errors (or each error) to be on a subsequence line below the property path.
    #   By default this is ":\n", i.e. propPath will be followed immediately by a colon and then a newline (since each error
    #   for that property is also printed on its own line). Could use ' => ' or even "\t" if trying to build a
    #   single-line string for the property and all its errors, perhaps as tab-delimited. Make sure to look at other options for help!
    attr_accessor :propSuffix
    # @return [String] When building per-property error messages, what text, if any, to put before each error that the property has? By default this
    #   is '    - ' because each error is going to be on its own line, indented w.r.t. the property path. If you want
    #   to have all errors on 1 line, could use '' (and see :errorSuffix).
    attr_accessor :errorPrefix
    # @return [String] When building per-property error messages, what text, if any, to put after each error that the property has? By default this is
    #   "\n" because each error is on its only line. If you want to have all errors on 1 line, could use ' ' so they are
    #   separated by single space, or '; ' for a semi-color separated list. Could even do "\t".
    attr_accessor :errorSuffix
    # @return [Symbol] When building per-property error messages, what field in the error object (Hash) to use for the error text? By default this is
    #   :fullMsg, which is a pre-generated string of the form: "ERROR {code}: {msg}". But you could just do :msg for the text only.
    #   or even just :code to dump the error codes without all the explanatory text.
    attr_accessor :errorField
    # @return [boolean] When building per-property error messages, should each error message (specifically) be wrapped, rather than leaving
    #   it all one long line? If set to @true@, then it will be word-wrapped using a line width of 78 (including
    #   {#errorPrefix}) ; otherwise the error message texts are left alone. The default is true.
    attr_accessor :errorWrap
    # @return [Array<String>] When building per-property error messages, and word wrapping is enabled (as is the default), what character or
    #   characters should be used to identify word-boundaries suitable for wrap-point? By default, this is [' ', '.', '?', ',', ';', ':']
    #   so that natural word wrapping is done via space and punctuation and so that long prop-paths (even ones where there are no/few spaces)
    #   get wrapped at the '.' in the property path, rather than breaking arbitrarily. Can change to some other set.
    attr_accessor :wordDelim
    attr_accessor :doingMemoization

    SUPPORTED_PROP_KEYS = { 'properties' => nil, 'items' => nil, 'value' => nil }
    MSG_PREFIXES = { :warning => 'WARNING', :error => 'ERROR' }
    MEMOIZED_INSTANCE_METHODS = [
    ]

    def initialize(kbDatabase=nil, dataCollName=nil)
      if(kbDatabase.nil? or (kbDatabase.is_a?(BRL::Genboree::KB::MongoKbDatabase) and kbDatabase.name.to_s =~ /\S/ and kbDatabase.db.is_a?(Mongo::DB)))
        @kbDatabase = kbDatabase
      else
        raise ArgumentError, "ERROR: if provided the kbDatabase arg must be a properly connected/active instance of BRL::Genboree::KB::MongoKbDatabase."
      end
      @dataCollName = dataCollName
      @modelValidator = BRL::Genboree::KB::Validators::ModelValidator.new()
      # Config/behavior flags
      @allowDupItems = false
      @castValues = false
      @disableCache = false
      @missingContentOk = nil
      # Tracking variables
      @modelCache = {}
      @contentNeeded = {}
      @needsCastingPropPaths = []
      @lastIdKey = @docId = nil
      @relaxedRootValidation = false
      @errorCountCap = 50
      @erroneousItemsCap = 5
      @parentSuggestionCap = 3
      @missingContentOkOverridden = false
      @propPrefix   = 'ERRORS FOR PROPERTY '
      @propSuffix   = ":\n"
      @errorPrefix  = '    - '
      @errorSuffix  = "\n"
      @errorField   = :fullMsg
      @errorWrap    = true
      @wordDelim    = [ ' ', '.', '?', ',', ';', ':' ]
      @doingMemoization = false
    end

    def clear()
      @validationErrors.clear() rescue nil
      @validationWarnings.clear() rescue nil
      @validationMessages.clear() rescue nil
      @modelCache.clear() rescue nil
      @contentNeeded.clear() rescue nil
      @needsCastingPropPaths.clear() rescue nil
      @model = @modelValidator = @validationErrors = @validationWarnings = @validationMessages = @lastIdKey = nil
      @docId = @contentNeeded = @needsCastingPropPaths = nil
      @modelCache = {}
      @contentNeeded = {}
      @needsCastingPropPaths = []
      return
    end

    # Override auto-determination of @missingContentOk (setting to nil restores auto-determination if was overridden)
    def missingContentOk=(arg)
      @missingContentOkOverridden = true
      @missingContentOk = ( arg.nil? ? nil : (arg ? true : false) )
    end

    # If it is safe to turn on memoization for this object and related object which help it do its job
    #   (e.g. ModelValidator instances and indirectly the BioOntology instances ModelValidator objects employ then
    #   call this method to setup memoization. This can have a HUGE
    #   performance effect when validating sets of docs! Saves on unnecessary object creation and unnecessary network connections by
    #   using RAM-caches. BUT it is ONLY safe if this object is ephemeral and won't survive cross web-request or exist for a long
    #   time in a server type process; that's because the caching will hide any changed ontology information, even fixes or temp problems.
    #   But if this object is just being used as local variable or a Controller instance variable (which goes away when request is done) or
    #   in a ephemeral script such as a tool-job, then definitely set this and call initMemoization!!!!
    # @note Once memoization is initialized, it can't be undone. The misleading @unmemoize_all@ method
    #   only clears the cache, leaving memoization happening on the very next call. Can't disable once enabled.
    # @note This initialized memoization for THIS INSTANCE. Other instance should be unaffected. This is good/safe
    #   given that memoization CANNOT BE DISABLED. This is why we didn't do it on the class in general be rather
    #   this instance's specific singleton_class. This is good though because it GENERALLY MEANS IT'S SAFE to enable
    #   for a validator instance because the life of that validator instance is restricted to the life of the request
    #   (or shorter), so we won't have out-of-date cached objects because we memoized at the global level via the class.
    #   Rather we just did it for this instance's singleton_class not the class in general.
    def initMemoization()
      @doingMemoization = true
      class << self
        extend Memoist
        # Memoize instance methods
        MEMOIZED_INSTANCE_METHODS.each { |meth| memoize meth }
      end
      # Init for @modelValidator too
      if( @modelValidator )
        @modelValidator.initMemoization()
      end
    end

    # Convenience method for iterating through each property in sensbile sort order, together with that property's
    #   specific Array<Hash> of error msg Hashes and running your code block on the prop path + error Array.
    #   Your code block is handed the full property path as the first argument and the array of error hashes as
    #   the second argument.
    # Illustrative example:
    #   docValidr.each_prop_errors { |path, errors|
    #     puts ">> #{path.inspect} => had codes: #{errors.reduce([]) { |ss, verr| ss << verr[:code] ; ss }.join(", ") }"
    #   }
    # @yieldparam [String] prop The full property path which has the errors.
    # @yieldparam [Array<Hash{Symbol, Object}>] errors The Array of error Hashes. Each error Hash has 3 keys:
    #   (1) :code - A Symbol with an error-specific code. Useful for filtering or testing.
    #   (2) :msg - A String text message, which can be subject to changes/tweaks describing the error. May have some dynamic
    #     contextual info related to the problem.
    #   (3) :fullMsg - A String containing a reasonable pre-formated message. Includes the type of message (e.g. ERROR or WARNING...here
    #     they will all be ERROR), the :code, and the :msg.
    def each_prop_errors( &blk )
      cb = ( block_given? ? Proc.new : blk )
      each_prop_feedbacks( :error, &cb )
    end

    # Convenience method for iterating through each property in sensbile sort order, together with that property's
    #   specific Array<Hash> of warning msg Hashes and running your code block on the prop path + warning Array.
    #   Your code block is handed the full property path as the first argument and the array of warning hashes as
    #   the second argument.
    # Illustrative example:
    #   docValidr.each_prop_warnings { |path, warnings|
    #     puts ">> #{path.inspect} => had codes: #{warnings.reduce([]) { |ss, vwarn| ss << vwarn[:code] ; ss }.join(", ") }"
    #   }
    # @yieldparam [String] prop The full property path which has the errors.
    # @yieldparam [Array<Hash{Symbol, Object}>] warnings The Array of warning Hashes. Each error Hash has 3 keys:
    #   (1) :code - A Symbol with an warning-specific code. Useful for filtering or testing.
    #   (2) :msg - A String text message, which can be subject to changes/tweaks describing the warning. May have some dynamic
    #     contextual info related to the problem.
    #   (3) :fullMsg - A String containing a reasonable pre-formated message. Includes the type of message (e.g. ERROR or WARNING...here
    #     they will all be WARNING), the :code, and the :msg.
    def each_prop_warnings( &blk )
      cb = ( block_given? ? Proc.new : blk )
      each_prop_feedbacks( :warning, &cb )
    end

    # Builds an Array of error message strings from {#validationErrors} hash, following a validateDoc().
    # @note Useful for updating other classes which assume validationErrors is an Array<String> rather than the more detailed,
    #   list of errors per propPath.
    # @note Each error message will roughly correspond to all the errors for a specific property.
    # @note Each error message will have MULTIPLE LINES, by default
    # @param [Hash{Symbol,Object}] opts Optional options hash for tweaking how message strings are built.
    #   @option opts [String] :propPrefix What text, if any, to put in front of each property path for which there
    #     are errors? Do include any space separating prefix from property path. By default this is 'ERRORS FOR PROPERTY ' as part
    #     of building a readable multi-line message string. Could set to '' to make more mininmalistic version output.
    #   @option opts [String] :propSuffix What text, if any, to put after each property path for which there are errors?
    #     Do include any newline if you want the errors (or each error) to be on a subsequence line below the property path.
    #     By default this is ":\n", i.e. propPath will be followed immediately by a colon and then a newline (since each error
    #     for that property is also printed on its own line). Could use ' => ' or even "\t" if trying to build a
    #     single-line string for the property and all its errors, perhaps as tab-delimited. Make sure to look at other options for help!
    #   @option opts [String] :errorPrefix What text, if any, to put before each error that the property has? By default this
    #     is '    - ' because each error is going to be on its own line, indented w.r.t. the property path. If you want
    #     to have all errors on 1 line, could use '' (and see :errorSuffix).
    #   @option opts [String] :errorSuffix What text, if any, to put after each error that the property has? By default this is
    #     "\n" because each error is on its only line. If you want to have all errors on 1 line, could use ' ' so they are
    #     separated by single space, or '; ' for a semi-color separated list. Could even do "\t".
    #   @option opts [Symbol] :errorField What field in the error object (Hash) to use for the error text? By default this is
    #     :fullMsg, which is a pre-generated string of the form: "ERROR {code}: {msg}". But you could just do :msg for the text only.
    #     or even just :code to dump the error codes without all the explanatory text.
    #   @option opts [boolean] :errorWrap When building per-property error messages, should each error message (specifically)
    #     be wrapped somehow, rather than leaving it all one long line? If set to @true@, then it will be word-wrapped using a
    #     line width of 78 (including {#errorPrefix}) ; otherwise the error message texts are left alone. The default is true.
    #     See other options for how to influence the wrapping to greatly affect error reporting layout.
    #   @option opts [Array<String>] When building per-property error messages, and word wrapping is enabled (as is the default),
    #     what character or characters should be used to identify word-boundaries suitable for wrap-points? By default, this is
    #     [' ', '.', '?', ',', ';', ':'] so that natural word wrapping is done via space and punctuation and so that long prop-paths
    #     (even ones where there are no/few spaces) get wrapped at the '.' in the property path, rather than breaking arbitrarily.
    #     Can change to some other set.
    # @return [Array<String>] The array of error messages.
    def buildErrorMsgs( opts={ :propPrefix => @propPrefix, :propSuffix => @propSuffix, :errorPrefix => @errorPrefix, :errorSuffix => @errorSuffix, :errorField => @errorField, :errorWrap => @errorWrap, :wordDelim => @wordDelim } )
      propPrefix  = (opts[:propPrefix] or @propPrefix)
      errorPrefix = (opts[:errorPrefix] or @errorPrefix)
      propSuffix  = (opts[:propSuffix] or @propSuffix)
      errorSuffix = (opts[:errorSuffix] or @errorSuffix)
      errorField  = (opts[:errorField] or @errorField)
      errorWrap   = (opts[:errorWrap] or @errorWrap)
      wordDelim   = (opts[:wordDelim] or @wordDelim)

      if( @validationErrors.is_a?(Hash) )
        validatorErrors = []
        self.each_prop_errors { |path, perrors|
          validatorErrors << perrors.reduce("#{propPrefix}#{path.inspect}#{propSuffix}") { |ss, error|
            errStr = "#{errorPrefix}#{error[errorField]}#{errorSuffix}"
            if(errorWrap)
              errStr.wordWrap!( 76, { :prefix => (' '*errorPrefix.size), :prefixWhich => :notFirst, :preUnwrap => false, :prefixWhich => :notFirst, :preUnwrap => true,:wordDelim => @wordDelim } )
              ss << "#{errStr}#{errorSuffix}"
            else
              ss << errStr
            end
            ss
          }
        }
      else # deprecated @validationErrors--probably some sub-class that still employs it like an Array--just return whatever it is
        validatorErrors = @validationErrors.dup
      end
      return validatorErrors
    end

    # Validate a document against a model
    # @param [BRL::Genboree::KB::KbDoc] doc the document to validate against a model
    # @param [BRL::Genboree::KB::KbDoc, String] modelDocOrCollName the model to use to validate against the model
    #   or the name of the collection to retrieve the model for; if providing a collection name, this class
    #   must be initialized with handles to Mongo so the model can be retrieved
    # @param [Boolean] restoreMongo_idKey if true, leave any Mongo "_id" fields intact within the doc;
    #   otherwise, remove them
    # @param [Hash] opts Additional args {Hash}. Keys:
    #   :castValues => Should validation cast/normalize the values in the doc according to the model domains? Required for saving into Mongo! Default is false.
    # @return [Boolean, Symbol] true/false indicates valid or invalid;
    #   :CONTENT_NEEDED means that the document is valid except for missing values where the model indicates a
    #     known content-generation domain
    # @raise [RuntimeError] if modelDocOrCollName is a String and the associated model could not be retrieved
    def validateDoc(doc, modelDocOrCollName=@dataCollName, restoreMongo_idKey=false, opts={ :castValues => @castValues, :needsCastCheck => @needsCastCheck, :allowDupItems => @allowDupItems })
      @modelValidator.clear() # its errors/warnings from previous doc validation runs
      @modelValidator.relaxedRootValidation = @relaxedRootValidation
      usingCachedModel = false
      @docId = @lastIdKey = nil
      @parentSuggestions = nil
      @allowDupItems = opts[:allowDupItems]
      @castValues = opts[:castValues]
      @needsCastCheck = opts[:needsCastCheck]
      @validationErrors = Hash.new { |hh,kk| hh[kk] = [] }
      @validationWarnings = Hash.new { |hh,kk| hh[kk] = [] }
      @validationMessages = []
      @contentNeeded = {}
      @needsCastingPropPaths = []
      # Determine @missingContentOk or not, unless it was explicitly set
      if( @missingContentOk.nil? or !@missingContentOkOverridden )
        @missingContentOk = ( standAloneMode? )
      end
      # Set flag indicating we've seen the "identifier"
      # - this will only get reset when entering an "items" list and restored when finished with it
      # - the doc identifier is the id amongst the set of documents and properties within an items
      #   list can have an identifier for id'ing an item amongst the set of items
      @haveIdentifier = false
      @uniqueProps = { :scope => :collection, :props => Hash.new{|hh, kk| hh[kk] = {} }}
      # Check model cache (to avoid repeatedly validating the same model doc)
      if((modelDocOrCollName.is_a?(String) and @modelCache.key?(modelDocOrCollName)) and !@disableCache)
        model = @modelCache[modelDocOrCollName]
        usingCachedModel = true
      elsif((modelDocOrCollName.acts_as?(Hash) and @modelCache.key?(modelDocOrCollName.object_id)) and !@disableCache)
        model = @modelCache[modelDocOrCollName.object_id]
        usingCachedModel = true
      else # cache disabled, or no corresponding model cached yet
        if(modelDocOrCollName.is_a?(String)) # name of a collection
          @dataCollName = modelDocOrCollName
          # - must have a @kbDatabase to work with then!
          if( !standAloneMode? )
            if(@kbDatabase.name.to_s =~ /\S/ and @kbDatabase.db.is_a?(Mongo::DB))
              pingResult = @kbDatabase.db.connection.ping
              if(pingResult.is_a?(BSON::OrderedHash) and pingResult['ok'] == 1.0)
                # - get ModelsHelper to aid us in getting the model
                modelsHelper = @kbDatabase.modelsHelper()
                modelKbDoc = modelsHelper.modelForCollection(@dataCollName)
                if(modelKbDoc.is_a?(BRL::Genboree::KB::KbDoc))
                  model = modelKbDoc.getPropVal('name.model') rescue nil
                  usingCachedModel = false # at least, not cached yet ; needs to be validated
                  if(model.nil?)
                    addError( '', :A09, "The model against which to validate the document does not have a valid 'model' sub-property where the actual model definition can be found. Cannot continue validation." )
                  end
                else # probably nil because failed
                  raise "ERROR: could not retrieve a model doc from the #{@dataCollName.inspect} collection within the #{@kbDatabase.name.inspect} GenboreeKB. Either the collection was created outside the Genboree framework, the model was deleted, or perhaps there is a spelling mistake (names are case-sensitive)?"
                end
              else
                raise "ERROR: the MongoKbDatabase object at DocValidator#kbDatabase is the correct kind of object and is setup correctly, but the Mongo server it points to cannot be reached. Perhaps it is down, or the host/port info is wrong, or the authorization credentials are wrong. Host: #{@kbDatabase.db.connection.host.inspect} ; port: #{@kbDatabase.db.connection.port.inspect} ; ping result:\n#{@kbDatabase.db.connection.ping.inspect}\n\n"
              end
            else
              raise "ERROR: the MongoKbDatabase object at DocValidator#kbDatabase is the correct kind of object but appears to not be setup or connected correctly. One or more of these are inappropriate: database name: #{@kbDatabase.name.inspect} ; driver class: #{@kbDatabase.db.class}"
            end
          else
            raise "ERROR: you have provided #{__method__}() with a collection name, but you did not initialize this object with connected BRL::Genboree::KB::MongoKbDatabase instance, nor did you add one after initialization. Can't query the collection without a database object!"
          end
        elsif(modelDocOrCollName.is_a?(BRL::Genboree::KB::KbDoc))
          model = modelDocOrCollName.getPropVal('name.model') rescue nil
          usingCachedModel = false # at least, not cached yet ; needs to be validated
          if(model.nil?)
            # No such property name.model. Assume modelDoc IS the model data structure, converted to a KbDoc but not actually property oriented:
            model = modelDocOrCollName
          end
        else # hash-like object which IS the model
          model = modelDocOrCollName
          usingCachedModel = false # at least, not cached yet ; needs to be validated
        end
      end

      # At this point, we should have the actual model, or we have @validationErrors (or we raised and didn't get here)
      if(@validationErrors.empty?)
        # Does the model look valid?
        @model = model
        if(usingCachedModel)
          modelDocValid = true
        else # not using cached model ... either don't have in cache yet or caching disabled
          # regardless, need to validate the model
          modelDocValid = @modelValidator.validateModel(@model)
          if(modelDocValid and !@disableCache)
            # Gather the parent suggestions for each property (not full path), so we can make suggestions for properties that
            #   might be misplaced.
            if(modelDocOrCollName.is_a?(String))
              @modelCache[modelDocOrCollName] = @model
            else # Hash or hash like
              @modelCache[modelDocOrCollName.object_id] = @model
            end
          end
        end
        # We are happy with the model. Get the child->parents suggestion map to help constructing error messages.
        @parentSuggestions = @modelValidator.parentSuggestions( @model )

        unless(modelDocValid)
          addError( '', :A10, "The model against which to validate the document is not itself valid. Cannot proceed with document validation without a valid model against which to check it. Cannot continue validation. Validation of the model reported these errors:\n  . #{@modelValidator.validationErrors.join("\n  .")}" )
        else
          # Start examining the doc
          if(doc)
            if( !doc.is_a?(BRL::Genboree::KB::KbDoc) and doc.acts_as?(Hash) )
              doc = BRL::Genboree::KB::KbDoc.new(doc)
            end
            validateRootProperty(doc)
            # Are we supposed to restore any mongo '_id' key we saw (if we did actually see one)
            if(restoreMongo_idKey and @lastIdKey)
              doc['_id'] = @lastIdKey
            end
          end
        end
      end
      @validationMessages << "DOC\t=>\t#{@validationErrors.empty? ? 'OK' : 'INVALID'} (#{@validationErrors.size})"
      if(@validationErrors.empty?)
        if(@contentNeeded.empty?)
          retVal = true
        else # there is content that may need to be filled in
          retVal = :CONTENT_NEEDED
        end
      else # there are errors
        retVal = false
      end
    end

    # For a given property name (not full path, just the local property name) and a list of POSSIBLE parent full propery paths
    #   for properties that have sub-props with that name, compose a partial validationError string with the parents as suggestions.
    def parentSuggestionStr( propName, parents )
      # If parents is empty or something, then will return no feedback (empty string)
      if( parents.is_a?(Array) and !parents.empty? )
        retVal = "There are other properties in the schema which have #{propName.inspect} as a sub-property."
        retVal << " For example, #{propName.inspect} could appear under: "
        parents.each_index { |ii|
          if( ii < @parentSuggestionCap )
            retVal << " #{parents[ii].inspect}"
            retVal << ',' unless(ii >= (parents.size - 1))
          elsif( ii ==  @parentSuggestionCap ) # We're over the cap, figure out how to end suggestions.
            if( ii == (parents.size - 1) ) # Then this IS the LAST one. Output it and stop with the suggestion.
              retVal << " or #{parents[ii].inspect}."
            else # there are this one AND more, end with a string to that effect
              retVal << " ...and #{ (parents.size - ii) + 1} more candidates."
            end
            break
          end
        }
      else
        retVal = ''
      end
      return retVal
    end

    # Validate multiple documents against a model
    # @see validateDoc
    #   [Hash] :invalid - map invalid document id to error
    #   [Hash] :error - map document id to an error (could not validate or invalidate document)
    #   [Array] :CONTENT_NEEDED - documents requiring content generation
    #   most likely latter but should be verified!
    # @todo how long does it take to make a hash key out of a kbDoc? use index instead?
    # @todo prefer uniformity of keys?
    # @todo Review how :CONTENT_NEEDED return value from validateDoc() will be handled.
    #   Note that new opts Hash gives some ability to affect this, but the handling of docStatus
    #   results in :CONTENT_NEEDED == add doc to invalid list. Is that right, always? Review.
    # @note deprecated - use dataCollectionHelper with save=false
    def validateDocs(docs, modelDocOrCollName=@dataCollName, restoreMongo_idKey=false, opts={ :castValues => @castValues, :needsCastCheck => @needsCastCheck })
      raise "ERROR: don't use #{__method__} until reviewing various calling and return scenarios where validateDoc() returns :CONTENT_NEEEDED"
      retVal = Hash.new { |hh, kk| hh[kk] = [] }
      retVal[:valid] = []
      retVal[:invalid] = {}
      retVal[:error] = {}
      docs.each_index { |ii|
        doc = docs[ii]
        docStatus = nil
        begin
          # 3 return values: true, false, :CONTENT_NEEDED
          docStatus = validateDoc(doc, modelDocOrCollName, restoreMongo_idKey, opts)
        rescue => err
          docStatus = err
        end
        if(docStatus == true)
          retVal[:valid].push(doc)
        elsif(docStatus == false)
          id = doc.getRootPropVal()
          retVal[:invalid][id] = @validationErrors
        elsif(docStatus.is_a?(Exception))
          retVal[:error].push[doc] = docStatus
        else # docStatus is nil, probably model propDef is messed up ; OR possibly :CONTENT_NEEDED was returned from validateDoc() ?
          id = doc.getRootPropVal()
          retVal[:invalid][id] = @validationErrors
        end
        @validationErrors.clear()
      }
      return retVal
    end

    def validateRootProperty(prop)
      # pathElems is an Array with the current elements of the property path
      # - A _copy_ gets passed forward as we recursively evaluate the model
      #   . A copy so we don't have to pop elements off the end when finishing a recursive call
      # - Used to keep track of exactly what property in the model is being assessed
      pathElems = []
      if( prop.acts_as?(Hash) and !prop.empty? )
        # IFF there is more than one root-level key, we'll see if we can
        # fix the situation due a likely/known cause: if we've been given a raw,
        # uncleaned MongoDB doc, see about removing any '_id' or :_id key.
        # - we only do this if there is more than one root key, which may allow the official
        #   root node to actually BE _id (interesting)
        if( prop.size > 1 )
          idVal = prop.delete('_id')
          idVal = prop.delete(:_id) if(prop.size > 1)
          @lastIdKey = idVal
        end
        # Should just be 1 key at this point...the root property name
        if(prop.size == 1)
          # Does it match the root property name?
          name = prop.keys.first
          begin
            pathElems << name
            if(name == @model['name'])
              autoContentDomain = @modelValidator.getDomainField(@model, :autoContent)
              rootDomain = @modelValidator.getDomainField(@model, :rootDomain)
              # Check certain root-specific things in the value-object for the root
              propValObj = prop[name]
              if( propValObj.acts_as?(Hash) )
                value = propValObj['value']
                # Root value must either be something, or an auto-content domain that is also ok for the root property.
                unless( propValObj and ( (!value.nil? and value.to_s =~ /\S/) or (autoContentDomain and rootDomain) ) or @relaxedRootValidation )
                  addError( pathElems, :B10, "The root property either has no value or the value is blank. This is not allowed for the document identifier." )
                end

                if( continue? )
                  # Check value of identifier vs domain
                  validInfo = @modelValidator.validVsDomain(value, @model, pathElems, { :castValue => @castValues, :needsCastCheck => @needsCastCheck })
                  if(validInfo.nil?) # check returned nil (something is wrong in the propDef) & details already recorded in @validationErrors of the modelValidator
                    @modelValidator.validationErrors.each { |verr|
                      verr = verr.sub(/^ERROR:\s*/, 'MODEL ERROR: ')
                      addError( pathElems, :B30, verr )
                    }
                  elsif(validInfo[:result] == :INVALID) # doc error, doesn't match domain
                    addError( pathElems, :B11, "The root property's value (#{value.inspect}) doesn't match the domain/type information specified in the document model (#{@model['domain'] ? @model['domain'].inspect : @modelValidator.class::FIELDS['domain'][:default]})." )
                  end

                  if( continue? )
                    # But parsing value could indicate we need to generate some content or some other complex instruction/return object.
                    result = validInfo[:result]
                    if(result == :CONTENT_NEEDED or result == :CONTENT_MISSING)
                      @contentNeeded[validInfo[:pathElems].join('.')] = validInfo
                      if(result == :CONTENT_MISSING and !@missingContentOk)
                        addError( pathElems, :B12, "The root property's value is missing content which should have been filled at this point." )
                      end
                    else
                      # Perform extra domain-specific validation
                      domainStr = @modelValidator.getDomainStr(@model)
                      validationErrors = validVsDomainAndColl(value, domainStr, pathElems)
                      validationErrors.each { |verrObj|
                        if( verrObj[:warnings].is_a?(Array) )
                          verrObj[:warnings].each { |warning|
                            addWarning( pathElems, verrObj[:code], warning )
                          }
                        else # must be about some error
                          addError( pathElems, verrObj[:code], verrObj[:msg] )
                        end
                      }
                    end

                    # Should we modify the input doc to have the casted/normalized value? Required for saving to database.
                    if(@castValues)
                      # Yes. Then the appropriate normalized value is in validInfo[:castValue]
                      propValObj['value'] = validInfo[:castValue]
                    end

                    # Are we tracking needsCasting?
                    if(@needsCastCheck and validInfo[:needsCasting])
                      @needsCastingPropPaths << pathElems.join('.')
                    end

                    @docId = value
                    if( propValObj.key?('items') and !@relaxedRootValidation )
                      addError( pathElems, :A32, "The root property cannot have a sub-items list, yet it does in this document. This is not allowed in the model definition, and thus also not allowed in documents purporting to follow the model. Cannot continue validation." )
                    end

                    if( continue? )
                      # Make sure root prop does not have anything besides properties or value
                      propValObj.each_key { |propKey|
                        unless( SUPPORTED_PROP_KEYS.key?( propKey ) or @relaxedRootValidation)
                          addError( pathElems, :B50, "The root property of a document can only have 'properties' or 'value' as keys and no others. You have this illegal key in your document root : #{propKey.inspect}" )
                          break unless( continue? )
                        end
                      }
                      # Root-specific stuff looks good so far.
                      @haveIdentifier = true
                      # At this point we should be able to validate the 'properties' under the root (if any).
                      validateProperties(name, propValObj, @model, pathElems.dup)
                    end # if( continue? )
                  end # if( continue? )
                end # if( continue? )
              else
                addError( pathElems, :A33, "The value object for the root property, like the value object for any property, must be a hash/map-like object. However, in this document it is a #{propValObj.class}, which is incorrect. Cannot continue validaton." )
              end # if( propValObj.acts_as?(Hash) )
            else
              addError( pathElems, :A31, "The document root property is not named #{@model['name'].inspect} as the model requires. Perhaps this document is for some other collection/entity due to a mix-up? Cannot continue validation, because false positive errors and wasting time are too likely." )
            end # if(name == @model['name'])
          rescue => err
            $stderr.debugPuts(__FILE__, __method__, "FATAL ERROR", "exception while validating doc vs its model! Exception when processing #{name.inspect} (current property path: #{name.inspect})")
            raise err # reraise...should be caught elsewhere in context but we made sure to log it once at least
          end
        else
          addError('', :A30, 'The document either has NO root property or there is more than 1 root property. GenboreeKB documents are singly-rooted and the root-level property is required and shall contain the unique document identifier. Cannot continue validation.')
        end # if(prop.size == 1)
      else # prop arg no good?
        if(@validationErrors.empty?) # then it's not some KbDoc problem we've already handled...it's something else
          addError('', :A20, 'The document cannot be validated at all, because it is not Hash-like object or has no content, even for the root property. Cannot continue validation.')
        end
      end # if( prop.acts_as?(Hash) and !prop.empty? )
      @validationMessages << "#{' '*(pathElems.size)}ROOT #{name.inspect}\t=>\t#{@validationErrors.empty? ? 'OK' : 'INVALID'} (#{@validationErrors.size})"
      return @validationErrors
    end

    # Validate sub-properties for a sub-document
    # @param [String] propName the name of the property that we are validating, mostly used for informative messages
    # @param [Hash] propValObj the sub-document whose properties we are validating, critically with key 'properties' pointing to
    #   sub-properties that are to be validated by this method
    # @param [Hash] propDef the property definition (from the model for this collection) for the property with the name propName
    # @param [Array<String>] pathElems array of path components from e.g. propPath.split(".") from the root property to this property,
    #   mostly for informational purposes
    # @return [Array<String>] set of validation errors explaining what went wrong
    def validateProperties(propName, propValObj, propDef, pathElems)
      begin
        # Any sub-props in the document, if any:
        subProps = propValObj['properties']
        # Definitions of sub-props from model, if any:
        subPropDefs = propDef['properties']
        # Find any required ones that are missing
        missingSubProps = [ ]
        if(subPropDefs.acts_as?(Array))
          subPropDefs.each { |subPropDef|
            if(subPropDef.acts_as?(Hash))
              subPropName = subPropDef['name']
              # Is this a required sub-property?
              if(subPropDef['required'])
                missingSubProps << subPropName if(!subPropName.nil? and subPropName =~ /\S/ and (subProps.nil? or !subProps.key?(subPropName)))
              end
              # Regardless, if we do have this sub-prop, validate it.
              if(subProps.acts_as?(Hash))
                if(subProps.key?(subPropName))
                  propValObj = subProps[subPropName]
                  validateProperty(subPropName, propValObj, subPropDef, pathElems.dup)
                  unless( continue? )
                    break
                  end
                end
              end
            end
          }
        end

        if( continue? )
          # Did we notice any missing sub-props?
          unless( missingSubProps.empty? )
            addError( pathElems, :P10, "Some required sub-properties are missing under this property. Specifically, the model definition says the following missing sub-properties must be present and correctly filled: #{missingSubProps.sort.map { |xx| xx.inspect }.join(', ')}." )
          end

          if( continue? )
            # Need to look for UNKNOWN sub-props that are not in the model (only checked known ones so far)
            if(subProps)
              if( subProps.acts_as?(Hash) )
                # If there are no properties defined for propName, then the doc can't have them!
                unless( subPropDefs.acts_as?(Array) )
                  addError( pathElems, :J50, "This property has sub-properties, where the model definition indicates there should be NO sub-properties. If you meant to provide sub-items, the items go in a list via the 'items' field, not the 'properties' field; otherwise, you have supplied illegal sub-properties which all need to be removed." )
                end

                if( continue? )
                  # . Deal with unknown sub-propertiies
                  knownProps = @modelValidator.knownPropsMap(subPropDefs, false) rescue nil # maybe there are none in model ; since accumulating now, need to be careful
                  subProps.each_key { |subPropName|
                    unless(knownProps and knownProps.key?(subPropName)) # skip if (1) there are sub-props here and (2) subPropName IS one of them
                      # Maybe it's just misplaced?
                      candidates = @parentSuggestions[subPropName]
                      if( candidates.is_a?(Array) and !candidates.empty? )
                        candidateMsg = parentSuggestionStr( subPropName, candidates )
                        addError( pathElems, :J51, "This property has an illegal sub-property #{subPropName.inspect}, which is not indicated in the model. Perhaps #{subPropName.inspect} was misplaced when the document was constructed? #{candidateMsg}" )
                      else # doesn't look like a misplaced property
                        addError( pathElems, :J52, "This property has an illegal sub-property #{subPropName.inspect}, which is not indicated in the model. Furthermore, #{subPropName.inspect} is not a valid property name anywhere in the document. Perhaps it is a typo; also keep in mind that property names are case-sensitive." )
                      end
                    end
                    break unless( continue? )
                  }
                end # if( continue? )
              else
                addError( pathElems, :J40, "The 'properties' field in the value object of this property is not a hash/map-like object whose keys are the sub-properties. Instead it is a #{subProps.class}, which is incorrect. If there are no sub-properties under this property in your document, remove the 'properties' field; if there are sub-properties, provide a compliant value for the 'properties' field. Cannot validate the sub-properties." )
              end # if( subProps.acts_as?(Hash) )
            end # if( subProps )
          end # if( continue? )
        end # if( continue? )
      rescue => err
        $stderr.debugPuts(__FILE__, __method__, "FATAL ERROR", "exception while validating doc vs model! Exception when processing property path: #{pathElems.is_a?(Array) ? pathElems.join('.').inspect : '{UNKNOWN/BROKEN}'}")
        raise err # reraise...should be caught elsewhere
      end
      @validationMessages << "#{' '*(pathElems.size)}SUB-PROPS OF #{pathElems.is_a?(Array) ? pathElems.join('.').inspect : '{UNKNOWN/BROKEN}'}\t=>\t#{@validationErrors.empty? ? 'OK' : 'INVALID'} (#{@validationErrors.size})"
      return @validationErrors
    end

    # @see #validateProperties
    def validateItems(propName, propValObj, propDef, pathElems)
      begin
        # . Skip if not proper value object or it doesn't have 'items' key (value object correctness should have been checked by this point)
        if( propValObj.acts_as?(Hash) and propValObj.key?('items') )
          subProps = propValObj['items']
          # Is the 'items' value is nil or empty string, then attempt to automatically covert to empty Array.
          if( !subProps.acts_as?(Array) and subProps.to_s !~ /\S/ )
            subProps = propValObj['items'] = [ ]
          end

          if( subProps.acts_as?(Array) ) # Get definitions of sub-properties of propName
            subPropDefs = propDef['items']
            # . If there are no items defined for propName, then the doc can't have them either1
            if( subPropDefs.acts_as?(Array) or subPropDefs.size != 1 )
              subPropDef = subPropDefs.first
              subPropName = subPropDef['name']
              # Arrange unique and identifier reset (scoped to items list)
              origUniqueProps = @uniqueProps
              @uniqueProps = { :scope => :items, :props => Hash.new{|hh, kk| hh[kk] = {} }}
              origHaveIdentifier = @haveIdentifier
              @haveIdentifier = false
              # Track items that have problems, but start new count for any nested items lists
              origBadItemCount = @badItemCount
              @badItemCount = 0
              # Check each item in the items list
              subProps.each_index { |ii|
                subProp = subProps[ii]
                itemPathElems = pathElems.dup.push("[#{ii}]")
                # . item look visitable?
                if( subProp.acts_as?(Hash) )
                  # IFF there is more than one root-level key for the item, we'll see if we can
                  # fix the situation due a likely/known cause: if we've been given a raw,
                  # uncleaned MongoDB doc, see about removing any '_id' or :_id key.
                  # - we only do this if there is more than one root key, which may allow the official
                  #   root node to actually BE _id (interesting)
                  # - much less likely to have _id here than at top-level of the document, but just in case
                  if( subProp.size > 1 )
                    subProp.delete('_id')
                    subProp.delete(:_id)
                  end
                  if( subProp.size == 1)
                    if( subProp.key?(subPropName) )
                      propValObj = subProp[subPropName]
                      validateProperty(subPropName, propValObj, subPropDef, itemPathElems)
                      if( continue? )
                        @badItemCount += 1 if( itemHasErrors?(itemPathElems) )
                        if( tooManyBadItems? )
                          break
                        end
                      else
                        break
                      end
                    else
                      @badItemCount += 1
                      addError( itemPathElems, :S22, "This item does not have the top-level/root property #{subPropName.inspect} as defined by the model. Each item is like a miniature document and must be singly-rooted with a property whose value is a unique item identifier, and the model indicates that the required root identifier property is named #{subPropName.inspect}. Cannot further validate this item nor any of its subordinates." )
                    end
                  else
                    @badItemCount += 1
                    addError( itemPathElems, :S21, "This item is not singly-rooted. Each item is like a miniature document and must be singly-rooted with a property whose value is a unique item identifier. Instead, this item #{subProp.size < 1 ? "is empty" : "is multi-rooted"}. Cannot further validate this item nor any of its subordinates." )
                  end
                else
                  @badItemCount += 1
                  addError( itemPathElems, :S20, "This item is not correctly structured. It is not a hash/map-like object whose keys are property names. Cannot further validate this item nor any of its subordinates." )
                end
                break if( tooManyBadItems? )
              }
              # Restore, now that we've finished drilling down within items list
              @uniqueProps = origUniqueProps
              @haveIdentifier = origHaveIdentifier
              @badItemCount = origBadItemCount
            else
              addError( pathElems, :F20, "Your document appears to have an items list at this property, but the model does not correctly define the schema for the items contained in this list. Cannot validate the subordinates of this items list due to underlying probelm with the model." )
            end # if( subPropDefs.acts_as?(Array) or subPropDefs.size != 1 )
          else
            addError( pathElems, :S10, "There appear to be items listed under this property because its value object has the 'items' field, BUT the value stored at that field is not an array/list-like object. Will not validate the subordinates of this items list. If you meant to supply the sub-properties, those go under the 'properties' field, not under the 'items' field." )
          end # if( subProps.acts_as?(Array) )
        end # if( propValObj.acts_as?(Hash) and propValObj.key?('items') )
      rescue => err
        $stderr.debugPuts(__FILE__, __method__, "FATAL ERROR", "exception while validating doc vs model! Exception when processing property path: #{pathElems.is_a?(Array) ? pathElems.join('.').inspect : '{UNKNOWN/BROKEN}'}")
        raise err # reraise...should be caught elsewhere
      end
      @validationMessages << "#{' '*(pathElems.size)}ITEMS LIST OF #{pathElems.is_a?(Array) ? pathElems.join('.').inspect : '{UNKNOWN/BROKEN}'}\t=>\t#{@validationErrors.empty? ? 'OK' : 'INVALID'} (#{@validationErrors.size})"
      return @validationErrors
    end

    # @see #validateProperties
    # @sets @contentNeeded if property has content to be generated by content generation framework
    def validateProperty(propName, propValObj, propDef, pathElems)
      #$stderr.puts "Validating property #{propName.inspect} of #{pathElems.join('.')} ; propValObj = #{propValObj.inspect}"
      if(propValObj)
        pathElems << propName
        if(propValObj.acts_as?(Hash)) # Can't validate deeper into this property unless this is true
          # Check either 'properties' or 'items', not both
          unless(propValObj.key?('properties') and propValObj.key?('items')) # Can't validate deeper into this property if has both.
            # Check value
            value = propValObj['value']
            domainStr = BRL::Genboree::KB::Validators::ModelValidator::FIELDS['domain'][:extractVal].call(propDef, "string")
            # . if fixed, then value must be missing or must match model
            if( domainStr == '[valueless]' and value.to_s =~ /\S/ )
              addError( pathElems, :M10, "The model defines this property as '[valueless]', yet it incorrectly has this value in the document: #{value.inspect}." )
            end

            if( continue? )
              # . Check that if value is supposed to be fixed then it indeed matches the fixed value
              if( propDef['fixed'] and (domainStr != '[valueless]') ) # We've correctly checked valueless above (nil/missing or '' empty string are ok)
                defaultVal = @modelValidator.getDefaultValue(propDef, pathElems)
                if( !defaultVal.nil? or (defaultVal.nil? and @modelValidator.validationErrors.empty?) )
                  unless(value == defaultVal)
                    addError( pathElems, :M11, "The model defines this property as having a fixed/static/unmodifiable value; i.e. the value is determined by the model. However, this property has the value #{value.inspect} in the document. If this property is present in the document, its value MUST be #{defaultVal.inspect}." )
                  end
                else # problem with default value in model ; get errors from @modelValidator
                  @modelValidator.validationErrors.each { |verr|
                    verr = verr.sub(/^ERROR:\s*/, 'MODEL ERROR: ')
                    addError( pathElems, :F10, verr )
                  }
                end
              end # if( propDef['fixed'] )

              if( continue? )
                # . Check that if unique, must not have seen this so far (uniqueness tracking resets under items lists)
                if( (propDef['unique'] or propDef['identifier']) and !@allowDupItems )
                  unless( checkUnique(value, pathElems) ) # this method knows whether to talk to MongoDB for collection-wide unique or just check current scope
                    addError( pathElems, :M12, "The model indicates this property's value must be unique. But its value in the document (#{value.inspect}) has been seen for this property already. For unique properties somewhere under an items list, the property must uniquely identify that item in the list--no other item in the list can have the same value for this property. For unique properties outside/above-any items list, no other *document* in the entire collection can have the same value for the property--the property is unique in the entire collection." )
                  end
                end
              end # if( continue? )
            end # if( continue? )

            if( continue? )
              # . Check that value matches domain
              #   - Are we in stand-alone mode AND the domain has special parseVal Proc for standalone mode??
              if( standAloneMode? and @modelValidator.hasStandaloneParseVal?( domainStr ) )
                # Yes, in stand-alone mode and this domain has some fallback parseVal for that
                validInfo = @modelValidator.validVsDomain( value, propDef, pathElems, { :castValue => @castValues, :needsCastCheck => @needsCastCheck, :standaloneMode => true } )
              else
                # No, hooked up to Genboree. Probably in API handler code or something.
                validInfo = @modelValidator.validVsDomain(value, propDef, pathElems, { :castValue => @castValues, :needsCastCheck => @needsCastCheck })
              end

              # Assess results of validation
              if( validInfo.nil? ) # check returned nil (something is wrong in the propDef) & details already recorded in @validationErrors of the modelValidator
                @modelValidator.validationErrors.each { |verr|
                  verr = verr.sub(/^ERROR:\s*/, '')
                  addError( pathElems, :F10, verr )
                }
              elsif( validInfo[:result] == :INVALID ) # doc error, doesn't match domain
                addError( pathElems, :M13, "The value for the property (#{value.inspect}) doesn't match the domain/type information from the model (#{propDef['domain'] ? propDef['domain'].inspect : @modelValidator.class::FIELDS['domain'][:default]})." )
              elsif(  standAloneMode? and @modelValidator.hasStandaloneParseVal?( domainStr ) )
                # If so, then alternative validation passed. But add the usual stand-alone CYA warning
                addWarning( pathElems, :a11, "Document is being validated in stand-alone / offline mode. Cannot fully validate the value of this path, because would have to consult Genboree which is not available in stand-alone mode. However, the value passed the special stand-alone validation check for #{domainStr.inspect} domains." )
              end

              if( continue? )
                # . Check the Object type spec here:
                if(propDef.key?('Object Type'))
                  objTypeValid = validateObjectTypeToPropValue(value, propDef)
                  unless( objTypeValid )
                    addWarning( pathElems, :m10, "The value (#{value.inspect}) for the #{pathElems.is_a?(Array) ? pathElems.join('.').inspect : '{UNKNOWN/BROKEN}'} property doesn't match the Object Type information specified in the document model (#{ BRL::Genboree::KB::Validators::ModelValidator::FIELDS["Object Type"][:extractVal].call(propDef, nil)}); it is not acceptable." )
                  end
                end

                # Parsing value could indicate we need to generate some content or some other complex instruction/return object.
                result = validInfo[:result]
                if(result == :CONTENT_NEEDED or result == :CONTENT_MISSING)
                  # Spike in scope Symbol for convenience
                  validInfo[:scope] = @uniqueProps[:scope]
                  @contentNeeded[validInfo[:pathElems].join('.')] = validInfo
                  if(result == :CONTENT_MISSING and !@missingContentOk)
                    addError( pathElems, :M14, "The property's value is missing content which should have been filled in by now." )
                  end
                else
                  # Perform extra domain-specific validation
                  validationErrors = validVsDomainAndColl(value, domainStr, pathElems)
                  validationErrors.each { |verrObj|
                    if( verrObj[:warnings].is_a?(Array) )
                      verrObj[:warnings].each { |warning|
                        addWarning( pathElems, verrObj[:code], warning )
                      }
                    else # must be about some error
                      addError( pathElems, verrObj[:code], verrObj[:msg] )
                    end
                  }
                end

                # Should we modify the input doc to have the casted/normalized value? Required for saving to database.
                if(@castValues)
                  # Yes. Then the appropriate normalized value is in validInfo[:castValue] because of how we called validVsDomain()
                  propValObj['value'] = validInfo[:castValue]
                end
                # If domain of current property is "numItems" and our model for that property has an items array, then we continue.
                if(@modelValidator.getDomainField(propDef, :type) == "numItems" and propDef.key?('items'))
                  # If propValObj doesn't have an items array, then the number of items currently associated with that property is 0.
                  unless(propValObj['items'])
                    propValObj['value'] = 0
                    # Otherwise, we just count the total number of items present in the items array and make that number the value of this property.
                    # Note that if the items array is 0, this will make the value 0 (since .size of an empty array is 0).
                  else
                    propValObj['value'] = propValObj['items'].size
                  end
                end
                # Are we tracking needsCasting?
                if(@needsCastCheck and validInfo[:needsCasting])
                  @needsCastingPropPaths << pathElems.join('.')
                end
              end # if( continue? )
            end # if( continue? )

            if( continue? )
              # Recurse, depending which kind of sub-elements it has (won't have both).
              # - Either doc or model has sub-properties? Check model because some may be REQUIRED but missing.
              if(propValObj.key?('properties') or propDef.key?('properties'))
                validateProperties(propName, propValObj, propDef, pathElems.dup)
              elsif(propValObj.key?('items')) # Only check if DOC has; item lists can inherently be empty so don't care about model at this time.
                validateItems(propName, propValObj, propDef, pathElems.dup)
              end

              if( continue? ) # Make sure it doesn't have any thing other than properties or items or value
                propValObj.each_key { |propKey|
                  unless( SUPPORTED_PROP_KEYS.key?( propKey ) or @relaxedRootValidation)
                    addError( pathElems, :J12, "The value object for this property contains keys/fields other than the supported 'properties', 'items', or 'value' fields. Specifically, it contains the invalid key: #{propKey.inspect}. This is not allowed because it is often a symptom of systematic mistakes or confusion." )
                    break unless( continue? )
                  end
                }
              end
            end
          else
            addError( pathElems, :J11, "The value object for this property contains BOTH the 'properties' and 'items' keys/fields. A property can have EITHER sub-properties (via 'properties') OR a homogenous list of sub-items (via 'items'), NOT BOTH.  Will not further validate this property nor any of its subordinates." )
          end
        else
          addError( pathElems, :J10, "The value object associated with the key #{propName.inspect} must be a hash/map-like object which employs only the standard keys/fields: 'value', and either 'properties' or 'items'. The value object here appears to be a #{propValObj.class}, which is incorrect. Will not further validate this property nor any of its subordinates." )
        end
      end
      @validationMessages << "#{' '*(pathElems.size)}PROP #{pathElems.is_a?(Array) ? pathElems.join('.').inspect : '{UNKNOWN/BROKEN}'}\t=>\t#{@validationErrors.empty? ? 'OK' : 'INVALID'} (#{@validationErrors.size})"
      return @validationErrors
    end # def validateProperty(propDef, pathElems, namesHash)

    def checkUnique(value, pathElems, seenUniqProps=@uniqueProps)
      retVal = false
      scope = seenUniqProps[:scope] rescue nil
      props = seenUniqProps[:props] rescue nil
      if(seenUniqProps.acts_as?(Hash) and props and props.acts_as?(Hash) and scope and (scope == :collection or scope == :items))
        if(scope == :items)
          # Check @uniqueProps to see if we've encountered this value for this property within
          # the current items scope.
          listIndex = pathElems.rindex { |xx| xx =~ /\[\d+\]/ }
          propPath = pathElems[0...listIndex].join('.')
          unless(props.key?(propPath) and props[propPath].key?(value))
            retVal = true
            props[propPath][value] = nil # mark as seen
          else
            retVal = false
          end
        else # scope must be :collection
          propPath = pathElems.join('.')
          if( !standAloneMode? )
            if(@dataCollName.is_a?(String) and @dataCollName =~ /\S/)
              # - need a dataCollectionHelper
              dataHelper = @kbDatabase.dataCollectionHelper(@dataCollName)
              propUnique = dataHelper.hasUniqueValue?(@docId, propPath, value)
              if(propUnique)
                retVal = true
                seenUniqProps[propPath] = value # mark as seen
              else
                retVal = false
              end
            else
              raise "ERROR: we have a MongoKbDatabase object available for checking uniqueness vs the actual collection, but DocValidator#docCollName doesn't contain a String with the name of the collection, so we can't do this. Instead it contains #{@docCollName.inspect}. If you are doing full document validations, including validating unique property values against the collection of documents, you need both the MongoKbDatabase object AND a valid collection name; if you are trying to do only a local validation (vs a local model file or model structure), do not provide a MongoKbDatabase argument when initializing this validator."
            end
          else # Stand-alone mode. Not really meaningful without checking actual collection ; check seenUniqProps [should be useless check]
            unless(seenUniqProps.key?(propPath) and seenUniqProps[propPath] == value)
              retVal = true
              seenUniqProps[propPath] = value # mark as seen
            end
            addWarning( pathElems, :a11, "Document is being validated in stand-alone / offline mode. Could not verify uniqueness of value among all documents in entire collection." )
          end
        end
      else
        raise "ERROR: the seenUniqProps argument must be a Hash with both the :scope and :props keys; valid scopes are :collection & :items, while :props maps to a Hash of unique properties already seen + the value seen."
      end
      return retVal
    end

    # Custom validation for the autoID domain increment uniqMode: require that the numeric
    #   part of the id is less than the value stored in the counter (in collection metadata document)
    # @param [String] value the value from a data document associated with the autoID increment domain
    # @param [String] propPath the BRL property path that the value is associated with
    # @param [Hash] pdom the parsed domain from
    #   BRL::Genboree::KB::Validators::ModelValidator::DOMAINS[{domain}][:parseDomain]
    # @param [String] dataCollName the name of the data collection that the @propPath@ applies to
    # @param [BRL::Genboree::KB::MongoKbDatabase] kbDatabase the object used to query for the counter
    # @return [Hash]
    #   :ok [Boolean] true if value is ok
    #   :msg [String] error message if ok is false
    #   :warnings [Array<String>] empty if everything went as expected, else 1+ warning strings
    def self.isIncrementOk(value, propPath, pdom, dataCollName, kbDatabase)
      rv = { :ok => false, :msg => "Internal Server Error", :warnings => [], :code => nil }
      extractFailCode = :C20
      extractFailMsg = "Could not extract numeric component from increment id value #{value.inspect}; it doesn't follow the increment id pattern defined by the model."

      if(dataCollName and kbDatabase) # these may be nil in stand-alone mode (i.e. just have model & doc, not fully integrated with mongo and a collection)
        # get the current value of the counter associated with this increment id
        mdh = kbDatabase.collMetadataHelper()
        counter = mdh.getCounter(dataCollName, propPath)
        if(counter.nil?)
          dbName = kbDatabase.db.name rescue nil
          rv[:code] = :D10
          rv[:msg] = "Could not retrieve the current value of the increment counter for this property in collection #{dataCollName.inspect} in database #{dbName.inspect}. Therefore, cannot validate the value #{value.inspect}. Likely reflects a serious infrastructure error."
          $stderr.debugPuts(__FILE__, __method__, "KB-ERROR", rv[:msg])
        else
          matchData = pdom[:uniqModeMatcher].match(value)
          if(matchData)
            if($1.nil?)
              rv[:code] = extractFailCode
              rv[:msg] = extractFailMsg
            else
              intPart = $1.to_i
              if(intPart <= counter)
                rv[:ok] = true
                rv[:msg] = "ok"
              else
                rv[:code] = :D11
                rv[:msg] = "The property value (#{value.inspect}) has a numeric component in excess of the last reserved AutoID for this property (#{counter.inspect}). You cannot make up your own ID with an imaginary/unofficial incremental component. Either allow the system to generate the AutoID properly using its auto-increment functionality or ask the system for a pre-reserved set of IDs which you can then employ in your document(s)."
              end
            end
          else
            rv[:code] = extractFailCode
            rv[:msg] = extractFailMsg
          end
        end
      else # in stand-alone mode (no mongo connect, no collection info; just model and doc)
        # Do basic format validation only
        matchData = pdom[:uniqModeMatcher].match(value.to_s)
        if($1.nil?)
          rv[:code] = extractFailCode
          rv[:msg] = extractFailMsg
        else
          rv[:ok] = true
          rv[:msg] = "ok"
          rv[:code] = :a10
          rv[:warnings] << "Document is being validated in stand-alone / offline mode. Could not verify increment counter properties vs actual collection-specific counter values, because in offline validation mode no querying of database is performed."
        end
      end
      return rv
    end

    def isIncrementOk(value, propPath, pdom, dataCollName=@dataCollName, kbDatabase=@kbDatabase)
      self.class.isIncrementOk(value, propPath, pdom, dataCollName, kbDatabase)
    end

    # Perform extra domain specific validation that requires information from the database
    #   (unlike BRL::Genboree::KB::Validators::ModelValidator#validVsDomain)
    # @param [Object] value the value we are validating
    # @param [String] domainStr the domain to validate the value against
    # @param [Array<String>] pathElems tokenized BRL propPath
    # @param [BRL::Genboree::KB::Validators::ModelValidator] modelValidator object to help with validation
    # @param [String] dataCollName the name of the data collection in @kbDatabase@
    # @param [BRL::Genboree::KB::MongoKbDatabase] kbDatabase object to help query the database for extra validation
    # @return [Array<String>] validationErrors -- empty if @value@ is valid vs @domainStr@
    def self.validVsDomainAndColl(value, domainStr, pathElems, modelValidator, dataCollName, kbDatabase, opts={})
      rv = []
      # Determine if this domain is an autoID increment domain that needs special validation
      unless(value == :CONTENT_MISSING or value == :CONTENT_NEEDED or value == "")
        # then we are not in a first pass content validation step
        domainRec = modelValidator.getDomainRec(domainStr)
        if(domainRec.nil?)
          $stderr.debugPuts(__FILE__, __method__, "KB-ERROR", "Could not validate value #{value.inspect} of #{pathElems.join(".")} against the domain #{domainStr.inspect} because no associated domain record could be found; we assume that this domain does not require any special validation against the collection and proceed.")
        else
          pdom = domainRec[:parseDomain].call( domainStr, { :factoryHelper => opts[:factoryHelper], :doingMemoization => opts[:doingMemoization] } )
          propPath = pathElems.join(".")
          isIncrement = (pdom.is_a?(Hash) and (pdom[:uniqMode] == "increment"))
          if(isIncrement)
            okObj = isIncrementOk(value, propPath, pdom, dataCollName, kbDatabase)
            unless(okObj[:ok])
              rv << { :code => okObj[:code], :msg => okObj[:msg] }
            end
            if( okObj[:warnings].is_a?(Array) and !okObj[:warnings].empty? )
              rv << { :code => okObj[:code], :warnings => okObj[:warnings] }
            end
          end
        end
      end
      return rv
    end
    def validVsDomainAndColl(value, domainStr, pathElems, modelValidator=@modelValidator, dataCollName=@dataCollName, kbDatabase=@kbDatabase)
      self.class.validVsDomainAndColl(value, domainStr, pathElems, modelValidator, dataCollName, kbDatabase, { :factoryHelper => @modelValidator, :doingMemoization => @doingMemoization } )
    end

    # Using a flattened model, select only the autoID domains with the increment uniqMode
    #   and retrieve their associated regexp (like the one used in validation) that can be
    #   used to extract the generated portion from their IDs
    # @see BRL::Genboree::KB::Helpers::ModelsHelper.flattenModel
    # @param [Hash] pathToDefMap map of model's property path to its property definition
    # @param [BRL::Genboree::KB::Validators::ModelValidator] object needed to retrieve domain record
    # @return [Hash] map of autoID increment property path to its associated regexp
    # @todo class method for getDomainRec then dont need modelValidator instance
    # @todo split the "select" function from the "map"?
    def self.mapAutoIdIncPathToMatcher(pathToDefMap, modelValidator)
      rv = {}
      uniqMode = "increment"
      pathToDefMap.each_key { |propPath|
        propDef = pathToDefMap[propPath]
        domainStr = propDef["domain"]
        domainRec = modelValidator.getDomainRec(domainStr)
        domainRec = modelValidator.getDomainRec("string") if(domainRec.nil?)

        re = nil
        if(domainRec[:type] == "autoID")
          pdom = domainRec[:parseDomain].call(domainStr)
          if(pdom[:uniqMode] == uniqMode)
            re = BRL::Genboree::KB::Validators::ModelValidator.composeAutoIdRegexp(pdom)
          end
        elsif(domainRec[:type] == "autoIDTemplate")
          pdom = domainRec[:parseDomain].call(domainStr)
          if(pdom[:uniqMode] == uniqMode)
            re = BRL::Genboree::KB::Validators::ModelValidator.composeAutoIdTemplateRegexp!(pdom)
          end
        end
        unless(re.nil?)
          # then this propDef is one of the autoID types
          rv[propPath] = re
        end
      }
      return rv
    end
    def mapAutoIdIncPathToMatcher(pathToDefMap, modelValidator=@modelValidator)
      self.class.mapAutoIdIncPathToMatcher(pathToDefMap, modelValidator)
    end

    # With a map of autoID increment property paths to their associated regexp and the added
    #   requirement that property paths are "propSel" paths (and not model property paths),
    #   compose a new map of property path to the maximum incremental generated id
    #   for that property in a data document (or nil if the value for that property is invalid)
    # @param [Hash] pathToMatcherMap as in return value of mapAutoIdIncPathToMatcher
    # @param [Hash] dataDoc a document for a user/data collection (not an internal collection)
    # @return [Hash] map of property path to max increment generated portion for that property
    #   or property path to nil if the generated portion could not be extracted/max'd
    # @see mapAutoIdIncPathToMatcher
    # @todo very similar to Util.validateAutoId
    # @todo this work will be repeated again in document validation
    # @todo distinguish between 2 types of failures?
    def self.mapAutoIdPathToMaxInDoc(pathToMatcherMap, dataDoc)
      rv = {}
      propSelector = BRL::Genboree::KB::PropSelector.new(dataDoc)
      pathToMatcherMap.each_key { |propPath|
        autoIdGenMatcher = pathToMatcherMap[propPath]
        values = propSelector.getMultiPropValues(propPath) rescue nil
        if(values.nil?)
          rv[propPath] = nil
        else
          anyFail = false
          valueGenParts = values.map { |value|
            matchData = autoIdGenMatcher.match(value)
            if(matchData)
              $1.to_i
            else
              anyFail = true
              break
            end
          }
          if(anyFail)
            rv[propPath] = nil
          else
            rv[propPath] = valueGenParts.max
          end
        end
      }
      return rv
    end

    # Get the maximum value for a generated autoID from a set of documents on a "best effort" basis:
    #   that is, if two documents are valid and one is invalid we will return the max of the valid two
    #   rather than error out
    # @note if all are invalid {propPath} => 0
    # @see mapAutoIdPathToMaxInDoc
    def self.mapAutoIdPathToMaxInDocs(pathToMatcherMap, dataDocs)
      globalPropToMax = Hash.new { |hh, kk| hh[kk] = 0 }
      dataDocs.each { |doc|
        autoIdPropToMax = mapAutoIdPathToMaxInDoc(pathToMatcherMap, doc)
        autoIdPropToMax.each_key { |propPath|
          localMax = autoIdPropToMax[propPath]
          globalMax = globalPropToMax[propPath]
          globalPropToMax[propPath] = [localMax.to_i, globalMax].max
        }
      }
      return globalPropToMax
    end

    # Checks if the value of the property with an 'Object Type' spec is in sync with
    # the collection name given in the Object Type. It also checks if the specified collection
    # does actually exists if the mongoKbDatabase instance is available within the class
    # @param [String] value of the property of interest
    # @param [Hash,nil] propDef the property definition from the model that will be used to validate the value
    #   mostly for its 'domain' key for lookup in DOMAINS. Can be nil if tgtColl is present
    # @param [BRL::Genboree::KB::MongoKbDatabase, nil] mdb class instance of BRL::Genboree::KB::MongoKbDatabase. Optional and
    #  will be used to check the presence of the collection name if present
    # @param [String] tgtColl the target collection collection given in the Object Type, is useful when the tgtColl
    #   is already known, can skip to extract it from the propDef
    # @param [Boolean] returnDocId true will return the doc id from the link if validation is a success
    def self.validateObjectTypeToPropValue(value, propDef=nil, mdb=nil, tgtColl=nil, returnDocId=false)
      retVal = false
      unless(tgtColl)
        objectType = BRL::Genboree::KB::Validators::ModelValidator::FIELDS['Object Type'][:extractVal].call(propDef, nil)
        tgtColl = $2 if(objectType and objectType =~ /^([^:]+):(.+)$/)
      end
      # must be a doc resource path as well as the coll must match the one in the Object Type value
      retVal = true if(tgtColl and value =~ /^(.*)coll\/([^\/\?]+)\/doc\/([^\/\?]+)(?:$|\/([^\/\?]+)$)/ and CGI.unescape($2) == tgtColl)
      # CAUTION! the collection names are a match, but there is no validation done here to check if the collection name mentioned actually exists or not.
      # So check that if a mongoKbDatabase instance is available, instead skip that step
      if(retVal and mdb)
        retVal = mdb.collections.include?(tgtColl)
      end
      retVal = CGI.unescape($3) if(retVal and returnDocId)
      return retVal
    end

    # check object type spec with the property value
    # @todo use mdb or not?
    def validateObjectTypeToPropValue(value, propDef, mdb=nil, tgtColl=nil, returnDocId=false)
      return self.class.validateObjectTypeToPropValue(value, propDef, mdb, tgtColl, returnDocId)
    end

    def itemHasErrors?( itemPath )
      # Need to scan the @validationErrors for entries related to this item or any NON-ITEM-LIST sub-doc
      if( itemPath.is_a?(Array) ) # Then probably pathElems array. Convert to path.
        itemPath = itemPath.join('.')
      elsif( !itemPath.is_a?(String) ) # Really, not the path nor path elements array ; maybe nil ; regardless convert to string
        itemPath = itemPath.to_s
      end
      errorKeys = @validationErrors.keys
      # Look for any prop paths for this item that DON'T involve sub-ordinate item list
      errorKeys.any? { |errorKey| errorKey.to_s =~ /^#{Regexp.escape(itemPath)}(?:[^\[]+)?$/ }
    end

    # Are we connected to an actual database for this validation run?
    def standAloneMode?()
      !(@kbDatabase.is_a?(BRL::Genboree::KB::MongoKbDatabase))
    end

    # Should we continue validating or have we accumulated too many errors?
    def continue?()
      ( (@errorCountCap.nil? or @validationErrors.nil? or (@validationErrors.size <= @errorCountCap) ) ? true : false )
    end

    def tooManyBadItems?( )
      ( ( @erroneousItemsCap.nil? or @badItemCount.nil? or (@badItemCount.to_i < @erroneousItemsCap ) ) ? false : true )
    end

    def each_prop_feedbacks( type, &blk )
      cb = ( block_given? ? Proc.new : blk )
      feedbacks = ( type == :warning ? @validationWarnings : @validationErrors )
      if( cb and feedbacks.is_a?(Hash) )
        feedbacks.keys.sort{ |aa,bb|
          rv = (aa.downcase <=> bb.downcase)
          rv = (aa <=> bb) if(rv==0)
          rv
        }.each { |path|
          verrs = feedbacks[path]
          cb.call( path, verrs )
        }
      end
    end

    def addError( propPath, code, msg )
      addFeedback( :error, propPath, code, msg )
    end

    def addWarning( propPath, code, msg )
      addFeedback( :warning, propPath, code, msg )
    end

    def addFeedback( type, propPath, code, msg )
      if( msg.to_s =~ /\S/ ) # must have non-blank message to add
        if( propPath.is_a?(Array) ) # Then probably pathElems array. Convert to path.
          propPath = propPath.join('.')
        elsif( !propPath.is_a?(String) ) # Really, not the path nor path elements array ; maybe nil ; regardless convert to string
          propPath = propPath.to_s
        end
        fullMsg = "#{MSG_PREFIXES[type]} #{code}: #{msg}"
        if( type == :warning )
          @validationWarnings[propPath] << { :code => code, :msg => msg, :fullMsg => fullMsg }
        else # assume :error
          @validationErrors[propPath] << { :code => code, :msg => msg, :fullMsg => fullMsg }
        end
      end
    end
  end
end ; end ; end ; end # module BRL ; module Genboree ; module KB ; module Validators
