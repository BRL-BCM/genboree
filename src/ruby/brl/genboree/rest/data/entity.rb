#!/usr/bin/env ruby
require 'md5'
require 'yaml'
require 'brl/util/util'
require 'brl/genboree/genboreeUtil'
require 'brl/activeSupport/activeSupport'

module BRL      #:nodoc:
module Genboree #:nodoc:
module REST     #:nodoc:
# == Preamble
# Exposing new Genboree entities in the API involves implementing a class that
# can create suitable _data representations_ for the API to return in HTTP responses.
# This involves the creation of classes within the
# <tt>{BRL::Genboree::REST::Data}[link:BRL/Genboree/REST/Data.html]</tt> namespace.
#
# Additionally, a corresponding resource class inheriting from
# <tt>{BRL::REST::Resource}[link:BRL/REST/Resource.html]</tt> and falling within the
# <tt>{BRL::REST::Resources}[link:BRL/REST/Resources.html]</tt> namespace must be
# findable at runtime by the API framework.
#
# == Exposing Genboree Resources
# Typically, and entity is represented by a singular resource representation class and
# a resource collection representation class. Since the collection classes tend to be very
# lightweight, they are often in the same source file with the corresponding singular
# representation class.
#
# The data representation source files live at <tt>brl/genboree/rest/data/</tt>.
#
# <b>Tasks for exposing new Genboree resources:</b>
# * Create a _resource_ class within <tt>{BRL::REST::Resources}[link:BRL/REST/Resources.html]</tt>
#   (store the code in a file under <tt>brl/genboree/rest/resources/</tt>)
#   * it must inherit from
#     <tt>{BRL::REST::Resources::GenboreeResource}[link:BRL/REST/Resources/GenboreeResource.html]</tt>
# * Create a <em>data representation</em> class within
#   <tt>{BRL::Genboree::REST::Data}[link:BRL/Genboree/REST/Data.html]</tt>
#   (store code in a file under <tt>brl/genboree/rest/data/</tt>)
#   * it must inherit from
#     <tt>{BRL::Genboree::REST::Data::AbstractEntity}[link:BRL/Genboree/REST/Data/AbstractEntity.html]</tt>
#
# <b>Tasks for modifying an existing Genboree resource:</b>
# * To add/modify an HTTP method, look for the appropriate resource class file under
#   <tt>brl/genboree/rest/resources/</tt> and implement or modify the corresponding #get, #put,
#   #delete, etc method as necessary.
# * If changes to the representations supported by the Genboree resource are needed,
#   look for the appropriate representation class file under <tt>/brl/genboree/rest/data/</tt>.
module Data

  # == Purpose: Abstract Genboree Resource _Representation_ class for _singular_ entities
  # This largely abstract class provides default implementations of core required methods
  # for any data representation class used by the API.
  #
  # The method implementations adhere to the Genboree API representation formats and in particular
  # provide extensive support for the structured representations that are wrapped in a common wrapper.
  #
  # The Genboree API framework and the classes within <tt>{BRL::REST::Resources}[link:BRL/REST/Resources.html]</tt>
  # assume these methods are available.
  #
  # In some specific cases, this Abstract Entity class is used directly rather than a subclass, since
  # it implements a working set of methods that can represent an empty (or rather, a non-) entity
  # which is useful for status-only representations for example.
  #
  # == Overview
  # All Genboree API representation subclasses inherit from this this class. Furthermore, where appropriate
  # for standard methods, the <tt>#super</tt> method should be called to have this parent class
  # do proper setup of any new object or properly do its part in any processing (although this is
  # rare, usually methods are overridden completely for specialized purposes).
  #
  # The default/core implementations here are generally multi-format aware and support generation of JSON, YAML,
  # and XML variants of the representation as long as conventions are followed.
  #
  # Because the implementations here handle a lot of the necessary work, subclasses only
  # need to implement small amounts of additional code or override just a handful of methods
  # for their specific representations.
  #
  # === Class Constants Subclasses must provide
  # Subclasses must set the the following class constants which the API server
  # framework will use to determine how to use the class:
  # [+SIMPLE_FIELD_NAMES+]  Array of top-level fields/attributes that just have
  #                         text or numeric values, rather than complex, nested data objects.
  #                         _Highly_ subclass-specific.
  # [+RESOURCE_TYPE+]       Some kind of +Symbol+ (capitalcase) that can be used to 'tag' the
  #                         class and which will be used as an XML tag name for _lists_ of
  #                         several entities of this kind.
  #                         _Highly_ subclass-specific.
  # [+FORMATS+]             The representation class supports, as an Array of upcase +Symbols+.
  #                         Unless some custom format is needed (e.g. :LFF) the default value provided
  #                         by this class is fine and subclasses need not override this.
  #
  # === Common Instance Variables
  # This abstract class provides several key instance variables to all subclasses. Subclasses should
  # make use of these and update the values stored within them as required. Several will be set
  # to proper values when <tt>#super</tt> is called within the subclass constructor.
  #
  # * <em><b>Refer to the attributes documented for this class to see what is available</b></em>
  #
  # === Common Interface Method Notes
  # Some methods implemented here are typically used in their default implementations and
  # never overridden, while others contain just stub implementations which must be
  # overridden by subclasses.
  #
  # <b>Typically, do not override:</b>
  # * #to_json, AbstractEntity.from_json
  # * #to_yaml, AbstractEntity.from_yaml
  # * #to_xml, AbstractEntity.from_xml
  #
  # <b>Typically, subclasses must override or provide:</b>
  # * #new (sensible constructor, make sure to include call to <tt>#super</tt>)
  # * #getFormatableDataStruct
  #
  # <b>Subclasses often override or provide:</b>
  # * #json_create
  # * #to_lff
  # * #method_missing
  #
  class AbstractEntity
    # Watch your scope for constants used in inherited methods (self.class::<CONSTANT> takes care of this)!

    # Map of format +Symbols+ to mime types
    FORMATS2CONTENT_TYPE =  { :JSON => 'application/json',
                              :JSON_PRETTY => 'application/json',
                              :XML => 'text/xml',
                              :RSS_XML => 'application/rss+xml',
                              :ATOM_XML => 'application/atom+xml',
                              :YAML => 'text/x-yaml',
                              :HTML => 'text/html',
                              :JS => 'application/x-javascript',
                              :LFF => 'text/plain' ,
                              :TABBED => 'text/plain',
                              :BED => 'text/plain' ,
                              :BED3COL => 'text/plain' ,
                              :BEDGRAPH => 'text/plain' ,
                              :GFF => 'text/plain' ,
                              :GTF => 'text/plain' ,
                              :WIG => 'text/plain',
                              :VWIG => 'text/plain',
                              :FWIG => 'text/plain',
                              :LAYOUT => 'text/plain',
                              :UCSC_BROWSER => 'text/plain',
                              :UCSC_HUB => 'text/plain',
                              :PNG => 'image/png',
                              :CHR_BAND_PNG => 'image/png',
                              :SCORE_CHART_PNG => 'image/png',
                              :FASTA => 'application/octet-stream'
                            }
    # JSON creation configuration settings
    JSON_PRETTY_STATE_CONFIG = JSON::Ext::Generator::State.new(
                        {
                          :indent => '  ',
                          :space => ' ',
                          :space_before => ' ',
                          :object_nl => "\n",
                          :array_nl => "\n",
                          :max_nesting => 5000
                        } )
    # JSON creation configuration settings
    JSON_STATE_CONFIG = JSON::Ext::Generator::State.new(
                        {
                          :indent => '',
                          :space => '',
                          :space_before => '',
                          :object_nl => '',
                          :array_nl => '',
                          :max_nesting => 5000
                        } )
    # Any basic name-value type fields; i.e. where the value is not a complex data structure but rather some text or a number.
    # Framework will do some automatic processing and presentation of those for you. Subclasses will override this, obviously.
    SIMPLE_FIELD_NAMES = []
    # Defaults for the simple fields, if not provided. "nil" means "must be provided in representation!"
    SIMPLE_FIELD_VALUES = []
    # What formats are supported, using the conventional +Symbols+. Subclasses may or may not override this.
    FORMATS = [ :JSON, :JSON_PRETTY, :XML, :YAML, :TABBED ]
    # A +Symbol+ naming the resource with a code-friendly (ok, XML tag-name friendly) name. This is currently used in
    # generating XML for _lists_...they will be lists of tags of this type (XML makes it hard to express certain natural things easily...)
    RESOURCE_TYPE = :AbstractRsrc

    # @return [String] The key for the reference url (when connect=yes)
    # @todo remove this and use JSON-LD @ref approach
    REFS_KEY = "#{RESOURCE_TYPE}_#{FORMATS.join('.')}"

    # Whether the representation should be wrapped in the standard Genboree wrapper or not.
    # Most should be, but selected representations (e.g. LFF) would not be.
    attr_accessor :doWrap
    # The resource type 'tag' for this entity. Mainly used by XML or in constructing the keys for #refs (framework sets this to the RESOURCE_TYPE, but can be programmatically manipulated here)
    attr_accessor :resourceType
    # What formats are supported for this entity representation (framework sets this to the FORMATS for the subclass, but can be programmatically manipulated here)
    attr_accessor :formats
    # Holds the references (links) relevant to this object, if any, in a +Hash+.
    attr_accessor :refs
    # What the root xml tag will be for xml representations for this entity (framework sets this to the RESOURCE_TYPE for the subclass, but can be programmatically manipulated here)
    attr_accessor :xmlRoot
    # Holds the serialized representation, if it has been generated for this entity.
    attr_accessor :serialized
    # The current status of composing a representation is held & communicated here. Many methods return the value also stored here to indicate success|failure, if appropriate.
    attr_accessor :statusCode
    # The current status message, especially useful when an error occurs (the error code being put into #statusCode of course)
    attr_accessor :msg
    # List of related job ids which may have been submitted as part of the request. This can be useful for say, conditional jobs and such.
    attr_accessor :relatedJobIds
    # Constructor. Matching GENBOREE INTERFACE.
    # [+doRefs+]      [optional; default=true] Do you want the "refs" field in any representation of this entity (i.e. make connections or save size/complexity of representation?)
    # [+doWrap+]      [optional; default=true] Wrap this entity in the common Genboree wrapper (disabled for recursive/contained entities)?
    # [+statusCode+]  [optional; default=:OK] Default HTTP response status code name.
    # [+msg+]         [optional; default="OK"] Default message to use in wrapper
    def initialize(doRefs=true, doWrap=true, statusCode=:OK, msg='OK', relatedJobIds=[])
      @refs = if(doRefs) then {} else false end      # set to false to avoid representing refs (regardless if there are any or not)
      @doWrap = doWrap
      @resourceType = self.class::RESOURCE_TYPE
      @formats = self.class::FORMATS
      @xmlRoot = self.class::RESOURCE_TYPE
      # Set up SIMPLE_INSTANCE_VARS for the class using SIMPLE_FIELD_NAMES, if not set already
      # - can be set explicitly in subclass code
      # - or in this initialize code by the first initialization for this class
      unless(self.class.const_defined?(:SIMPLE_INSTANCE_VARS))
        arr = self.class.const_set(:SIMPLE_INSTANCE_VARS, [])
        self.class::SIMPLE_FIELD_NAMES.each { |field|
          instanceVarSym = "@#{field}".to_sym
          arr << instanceVarSym
        }
      end
      self.setStatus(statusCode, msg, relatedJobIds)
    end

    # GENBOREE INTERFACE. Delegation-compliant is_a? called "acts_as?()".
    #   Override in sub-classes if the structured data representation is not a Hash or hash-like.
    #   Most entities do use Hash-like structured data representations (except lists, which indeed
    #   override this method, as you can find out for {AbstractEntityList} below).
    def acts_as?(aClass)
      return (aClass == Hash ? true : false)
    end

    # GENBOREE INTERFACE. Wrap data object such that serialization/stringification will have common Genboree envelope
    # [+data+]    Data object to wrap.
    # [+returns+] +Hash+ based data structure that had the +data+ parameter wrapped.
    def wrap(data=nil)
      wrapper = if(@doWrap)
                  {
                    "data" => data,
                    "status" => self.getStatus()
                  }
                else # don't wrap
                  data
                end
      return wrapper
    end

    # GENBOREE INTERFACE. Set status/feedback fields for wrapper.
    # [+statusCode+]  Default HTTP response status code name.
    # [+msg+]         Default message to use in wrapper.
    # [+returns+]     +Array+ with the status code and the message.
    def setStatus(statusCode=:OK, msg="OK", relatedJobIds=[])
      @statusCode, @msg, @relatedJobIds = statusCode, msg, relatedJobIds
    end

    # GENBOREE INTERFACE. Get status as a Hash object.
    # [+returns+] Gets the "status" +Hash+ which contains the standardized fields "statusCode" and "msg".
    def getStatus()
      statusHash = {}
      statusHash["statusCode"] = @statusCode.to_s
      statusHash["msg"] = @msg
      statusHash['relatedJobIds'] = @relatedJobIds if(@relatedJobIds and !@relatedJobIds.empty?)
      return statusHash
    end

    # GENBOREE INTERFACE. Set the refs appropriately for this entity
    # [+refs+]    [optional; default=nil] Either a +Hash+ of representation types mapped to resource URIs, or +nil+ or +false+.
    #             The default +nil+ and +false+ will wipe out any refs associated with this entity and will suppress the output
    #             when serialized of the "refs" field completely.
    # [+returns+] @refs
    def setRefs(refs=nil)
      if(refs.nil? or refs == false)
        @refs = false
      else # want refs (arg ought to be a Hash or something)
        @refs = refs
      end
      return @refs
    end

    # GENBOREE INTERFACE. Get a +Hash+ or +Array+ that represents this entity.
    # - used by the default implementations of <tt>to_*()</tt> methods
    # - override in sub-classes
    # - this data structure will be used in the serialization implementations
    # [+returns+] A +Hash+ or +Array+ representing this entity (or collection of entities)
    #             wrapped in the standardized Genboree wrapper, if appropriate.
    #             <i>Entity class specific</i>
    def getFormatableDataStruct()
      data = {}
      data['refs'] = @refs if(@refs)
      retVal = self.wrap(data)  # Wrap the data content in standard Genboree JSON envelope
      return retVal
    end

    # @api RestDataEntity
    # GENBOREE INTERFACE. Subclasses inherit; override if subclass has more than just its SIMPLE_FIELD_VALUES
    # or if the SIMPLE_FIELD_VALUES don't match the @-style instance variable names.
    #
    # Get a {Hash} or {Array} that represents this entity.
    # Generally used to convert to some String format for serialization. Especially to JSON.
    # @note Must ONLY use Ruby primitives (String, Fixnum, Float, booleans) or
    #   basic Ruby collections (Hash, Array). No custom classes.
    # @param [Boolean] wrap Indicating whether the standard Genboree wrapper should be used to
    #   contain the representation or not. Generally true, except when the representation is
    #   within a parent representation [which is likely wrapped].
    # @return [Hash,Array] representing this entity (or collection of entities)
    #   wrapped in the standardized Genboree wrapper, if appropriate.
    def toStructuredData(wrap=@doWrap)
      # Use the SIMPLE_INSTANCE_VARS constant (built once for class at runtime from SIMPLE_FIELD_NAMES)
      # to create a simple hash representation
      data = {}
      sivs = self.class::SIMPLE_INSTANCE_VARS
      sfns = self.class::SIMPLE_FIELD_NAMES
      sivs.each_index { |ii|
        instanceVarSym = sivs[ii]
        fieldName = sfns[ii]
        data[fieldName] = self.instance_variable_get(instanceVarSym)
      }
      data['refs'] = @refs if(@refs)
      if(wrap)
        retVal = self.wrap(data) # Wrap the data content in standard Genboree JSON envelope
      else
        retVal = data
      end
      return retVal
    end

    # GENBOREE INTERFACE. Serialize resource to a supported format.
    # Not commonly overridden in subclasses except in special cases; default implementation
    # calls appropriate conversion methods.
    # [+formatSym+] Stringify/serialize this entity as this format.
    # [+returns+]   Status +Symbol+ (<tt>:OK</tt> for success or other for error)
    def serialize(formatSym)
      #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "formatSym: #{formatSym.inspect}")
      retVal = :OK
      begin
        if(self.class::FORMATS.include?(formatSym))
          @serialized = if(formatSym == :JSON)
                          to_json()
                        elsif(formatSym == :JSON_PRETTY)
                          to_jsonPretty()
                        elsif(formatSym == :YAML)
                          to_yaml()
                        elsif(formatSym == :XML)
                          to_xml()
                        elsif(formatSym == :LFF)
                          to_lff()
                        elsif(formatSym == :TABBED)
                          to_tabbed()
                        elsif(formatSym == :UCSC_HUB)
                          to_ucsc()
                        else
                          retVal = :'Unsupported Media Type'
                          AbstractEntity.representError(formatSym, retVal, "BAD_FORMAT: bad resource representation format requested (format: #{formatSym})")
                        end
        else
          retVal = :'Not Implemented'
          @serialized = AbstractEntity.representError(formatSym, retVal, "NOT_IMPLEMENTED: This resource cannot be represented in the format #{formatSym}")
        end
      rescue => err
        @serialized = "FATAL: Due to an unexpected error, failed to represent this resource as #{formatSym}"
        retVal = :'Internal Server Error'
        BRL::Genboree::GenboreeUtil.logError(@serialized, err, formatSym)
      end
      return retVal
    end

    # GENBOREE INTERFACE. Take serialized form in some format, and create entity object.
    # Not commonly overridden in subclasses except in special cases; default implementation
    # calls appropriate conversion methods.
    # @param [Object]  serializedIO IO-like object containing formatted data (typically is <tt>rack.input</tt>
    #   [i.e. a <tt>Rack::Request.body</tt> is the arg here], _must_ respond to #read, #gets, #each, and never be closed)
    # @param [Symbol] formatSym The format of the serialized data.
    # @param [Boolean] exceptionPassThrough Set true if the caller can handle any raised exception due to bad parsing or something. This is useful if
    #    you want to extract the specific error message which may have details about specifically what went wrong, say
    #    for the user to read in an email (maybe so they can fix the issue!).
    #    Otherwise, a generic return of :'Unsupported Media Type' will be returned and the calling code will make some
    #    appropriate generic explanation. (This latter use is older and should be discouraged; GenboreeError instances are
    #    especially informative.) @todo the methods called by this one to parse various formats
    #    should also support the exceptionPassThrough
    # @param [Hash] opts An options hash with entity specific options
    # @return [Object] Instance of entity object or error +Symbol+
    def self.deserialize(serializedIO, formatSym, exceptionPassThrough=false, opts={})
      #$stderr.debugPuts(__FILE__, __method__, "DEBUG", ">>>> io class: #{serializedIO.class} ; format: #{formatSym.inspect} ; exceptionPassThrough: #{exceptionPassThrough.inspect}")
      retVal = :'Unsupported Media Type'
      # read serialized string into memory (serialized data typically 'small' so this should be fine)
      serializedStr = ''
      unless(serializedIO.nil?)
        if(serializedIO.is_a?(String)) # then not an IO at all, but already the value we want
          serializedStr = serializedIO.strip
        else # IO or IO-like; use carefully
          # Ensure we're reading from the very beginning
          serializedIO.rewind() if(serializedIO.respond_to?(:rewind))
          # Read all content into memory....
          serializedStr = serializedIO.read()
          serializedStr.strip!
        end
      end
      begin
        # Convert from <FORMAT> to an entity
        $stderr.debugPuts(__FILE__, __method__, "TIME", "before deserialization of #{formatSym.to_s}")
        if(formatSym == :JSON or formatSym == :JSON_PRETTY)
          jsonObj = JSON.parse(serializedStr)
          retVal = self.from_json(jsonObj)
        elsif(formatSym == :YAML)
          yamlObj = YAML.load(serializeStr)
          retVal = self.AbstractEntity.from_yaml(yamlObj)
        elsif(formatSym == :XML)
          xmlObj = Hash.AbstractEntity.from_xml(serializedStr)
          # extract the actual data obj...it will be whatever is stored under the root key of xmlObj:
          xmlDataObj = xmlObj[xmlObj.keys.first]
          retVal = self.AbstractEntity.from_xml(xmlDataObj)
        elsif(formatSym == :LFF)
          retVal = self.from_lff(serializedStr)
        elsif(formatSym.to_s.downcase =~ /^tabbed/) # Since there can be multiple types of tabbed formats.(see kb/{kb}/docs)
          opts[:format] = formatSym
          retVal = self.from_tabbed(serializedStr, opts)
        elsif(formatSym == :UCSC_HUB)
          retVal = self.from_ucsc(serializedStr)
        elsif(formatSym == :UCSC_HUB)
          retVal = self.from_ucsc(serializedStr)
        end
        $stderr.debugPuts(__FILE__, __method__, "TIME", "after deserialization of #{formatSym.to_s}")
        #$stderr.debugPuts(__FILE__, __method__, "DEBUG", ">>>> retVal (no err):\n\n#{retVal.inspect}\n\n")
      rescue => err
        if(!err.is_a?(BRL::Genboree::GenboreeError))
          retError = BRL::Genboree::GenboreeError.new(:'Unsupported Media Type', "There was an error parsing the request body, please check the format and entity type. (#{err.class}: #{err.message}) ", err, true)
        else
          retError = err
        end
        #$stderr.debugPuts(__FILE__, __method__, "DEBUG", ">>>> retError:\n\n#{retError.inspect}\n\n")
        if(exceptionPassThrough)
          retVal = retError
        else
          retVal = :'Unsupported Media Type'
        end
      end
      return retVal
    end

    # GENBOREE INTERFACE. Builds a standard +Hash+ suitable for the "refs" field of entities
    # possessing a refs field. Not commonly overridden in subclasses except in special cases;
    # the standard instance variables (object state) is used by this implementation to do the right thing.
    # [+templateUrl+] A +String+ to act as the rsrcURI (everything minus the gb* auth-parameters)
    #                 to build from. It is assumed to be the canonical (format-less) URL.
    # [+returns+]     @refs, suitably updated
    def makeRefsHash(templateUrl)
      #retVal = @refs
      #if(@refs)
      #  templateUrl.strip!
      #  templateUrl << "?" unless(templateUrl.include?("?"))
      #  # Add 'canonical' URL (templateUrl assumed to be canonical one)
      #  @refs["#{@resourceType}_#{self.class::FORMATS.join('.')}"] = templateUrl
      #else
      #  retVal = nil
      #end
      #return retVal

      retVal = nil
      if(@refs)
        # The following seems to be wasteful...does a full string scan in order to add a useless "?" at the end?
        # ...maybe to support bad URL parsing & construction code which doesn't build properly from URI pieces.
        #templateUrl.strip!
        #templateUrl << "?" unless(templateUrl.include?("?"))

        # Add 'canonical' URL (templateUrl assumed to be canonical one)
        @refs[self.class::REFS_KEY] = templateUrl
        retVal = @refs
      end
      return retVal
    end

    # JSON INTERFACE. Implement a standard #to_json method.
    # Not commonly overridden in subclasses except in special cases.
    # The default implementation here converts the data structure prepared by +getFormatableDataStruct()+
    # directly to JSON, so as long as that is sensibly implemented, there's no need to override.
    # [+returns+] +String+ containing a representation of this data, in JSON format.
    def to_json(state=self.class::JSON_STATE_CONFIG, depth=0, *args)
      #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "state:\n#{JSON.pretty_generate(state)}\n\n")
      t1 = Time.now
      retVal = toStructuredData()
      # Sameer: use JSON.generate() just for checking speeds (appears to be twice as fast)
      #retVal =  retVal.to_json(state, *args) # Not much different than JSON.pretty_generate() but we can tweak/customize
      retVal = JSON.generate(retVal)
      return retVal
    end

    # JSON INTERFACE. Implement a standard #to_json method.
    # Not commonly overridden in subclasses except in special cases.
    # The default implementation here converts the data structure prepared by +getFormatableDataStruct()+
    # directly to JSON, so as long as that is sensibly implemented, there's no need to override.
    # [+returns+] +String+ containing a representation of this data, in JSON format.
    def to_jsonPretty(state=self.class::JSON_PRETTY_STATE_CONFIG, depth=0, *args)
      #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "state:\n#{JSON.pretty_generate(state)}\n\n")
      t1 = Time.now
      retVal = toStructuredData()
      #retVal =  retVal.to_json(state, *args) # Not much different than JSON.pretty_generate() but we can tweak/customize
      retVal = JSON.pretty_generate(retVal)
      return retVal
    end

    # JSON INTERFACE: Implement a standard AbstractEntity.from_json method to parse a JSON
    # representation. If the entity is not complex (just has the fields listed in
    # its +SIMPLE_FIELD_NAMES+ +Array+), then the default implementation will make use
    # of the #jsonCreateSimple helper method to do the conversion--no need to override.
    # [+parsedJsonResult+]  The +Hash+ or +Array+ resulting from parsing the JSON string.
    # [+returns+]           Instance of this class, whose state comes from data within +parsedJsonResult+.
    def self.from_json(parsedJsonResult)
      retVal = self.jsonCreateSimple(parsedJsonResult, self::SIMPLE_FIELD_NAMES)
      return retVal
    end

    # JSON INTERFACE: Implement a standard AbstractEntity.from_json method to parse a JSON
    # representation. If the entity is not complex (just has the fields listed in
    # its +SIMPLE_FIELD_NAMES+ +Array+), then the default implementation will make use
    # of the #jsonCreateSimple helper method to do the conversion--no need to override.
    # [+parsedJsonResult+]  The +Hash+ or +Array+ resulting from parsing the JSON string.
    # [+returns+]           Instance of this class, whose state comes from data within +parsedJsonResult+.
    def self.from_jsonPretty(parsedJsonResult)
      return self.from_json(parsedJsonResult)
    end

    # JSON INTERFACE: Implement a standard <tt>AbstractEntity.json_create(obj)</tt> method.
    # This class method defined by the JSON library allows instances of this class
    # to be created from -parsed- JSON (i.e. a +Hash+ or +Array+ resulting from <tt>JSON::parse(jsonStr))</tt>.
    # Default implementation calls +from_json+ so overriding/customizing code can go there and
    # avoid overriding this method.
    # [+parsedJsonResult+]  The +Hash+ or +Array+ resulting from parsing the JSON string.
    # [+returns+]           Instance of this class, whose state comes from data within +parsedJsonResult+.
    def self.json_create(parsedJsonResult)
      return self.from_json(parsedJsonResult)
    end

    # TABBED INTERFACE.
    # Helper method to properly escape tab-delimited data
    def esc(str)
      return str.gsub(/\r/, "\\r").gsub(/\n/, "\\n").gsub(/\t/, "\\t") if(str.is_a?(String))
      return str
    end

    # TABBED INTERFACE. This is currently just a place holder, as it can't
    # really do anything outside of specific entities.  This method must
    # be overridden by subclasses with an actual implementation in order
    # to support tabbed output.
    # [+returns+] Always returns empty +String+.
    def to_tabbed()
      return ""
    end

    # TABBED INTERFACE. This is currently just a place holder, as it can't
    #   really do anything outside of specific entities.  This method must be
    #   overridden by subclasses with an actual implementation in order to
    #   support creation from a tab-delimited string.
    # @param [String] data A multi-line string with tab-delimited data to be parsed.  Must contain a header
    #   line (line beginning with first non-whitespace character of "#")
    # @param [Hash] opts Any other options specific to how the subclass implements this method
    #   and/or needs info in order to interpret the tabbed file are found in this opts {Hash}.
    #   i.e. you can use named parameters for this kind of thing. If you don't need it, just ignore it.
    # @return Always returns @nil@ by default, but real implementations in subclasses return some
    #   kind of {BRL::Genboree::REST::Data::AbstractEntity} subclass.
    def self.from_tabbed(data, opts={})
      return nil
    end

    # UCSC INTERFACE. Entity specific; subclasses must override.
    def to_ucsc()
      err = BRL::Genboree::GenboreeError.new(:"Not Implemented", "This entity cannot be represented in UCSC format")
      raise err
    end

    # UCSC INTERFACE. Entity specific; subclasses must override.
    def self.from_ucsc(data)
      err = BRL::Genboree::GenboreeError.new(:"Not Implemented", "This entity cannot be represented in UCSC format")
      raise err
    end

    # YAML INTERFACE. Implement a standard #to_yaml method.
    # Not commonly overridden in subclasses except in special cases.
    # The default implementation here converts the data structure prepared by +getFormatableDataStruct()+
    # directly to YAML, so as long as that is sensibly implemented, there's no need to override.
    # [+returns+] +String+ containing a representation of this data, in YAML format.
    def to_yaml(*args)
      retVal = getFormatableDataStruct()
      return retVal.to_yaml(*args)
    end

    # YAML INTERFACE: Implement a standard <tt>AbstractEntity.AbstractEntity.from_yaml(parsedJsonResult)</tt> method.
    # Default implementation calls +json_create+ so overriding/customizing code can go there and
    # avoid overriding this method. This works in most cases the parsed YAML result is the same
    # as a parsed JSON result (same +Hash+ or +Array+)
    # [+parsedYamlResult+]  The +Hash+ or +Array+ resulting from parsing the YAML string.
    # [+returns+]           Instance of this class, whose state comes from data within +parsedYamlResult+.
    def self.from_yaml(parsedYamlResult)
      retVal = self.json_create(parsedYamlResult, self::SIMPLE_FIELD_NAMES)
      return retVal
    end

    # XML INTERFACE. Implement a standard #to_xml method, backed by ActiveSupport's #to_xml methods
    # The default implementation here converts the data structure prepared by #getFormatableDataStruct
    # [+options+] [optional; default={}] Options influencing the parsing of the XML. Passed to the
    #             +to_xml+ method provided by ActiveSupport.
    # [+returns+] +String+ containing a representation of this data, in XML format.
    def to_xml(options={})
      retVal = getFormatableDataStruct()
      options[:root] = @xmlRoot
      options[:dasherize] = false
      return retVal.to_xml(options)
    end

    # XML INTERFACE: Implement a standard <tt>AbstractEntity.AbstractEntity.from_xml(parsedXmlResult)</tt> method.
    # Default implementation calls +json_create+ so overriding/customizing code can go there and
    # avoid overriding this method. This works in most cases the parsed XML result is the same
    # as a parsed XML result (same +Hash+ or +Array+)
    # [+parsedXmlResult+]  The +Hash+ or +Array+ resulting from parsing the XML string.
    # [+returns+]          Instance of this class, whose state comes from data within +parsedXmlResult+.
    def self.from_xml(parsedXmlResult)
      # Extract the actual content, which is everything under the xml root (first and only key)
      parsedXmlResult = parsedXmlResult[parsedXmlResult.keys.first]
      # Pass resulting hash/array object to json_create
      retVal = self.json_create(parsedXmlResult)
      return retVal
    end

    # GENBOREE INTERFACE. Get "Content-Type" header value.
    # Uses the +FORMATS2CONTENT_TYPE+ +Hash+ of this class to get the appropriate
    # mime type for a format (provided as a +Symbol+). Almost never needs to be
    # overridden as long as +FORMATS2CONTENT_TYPE+ is set up correctly.
    # [+formatSym+] A supported format for this data representation, as a +Symbol+.
    # [+returns+]   A suitable "Content-Type" header value for the format provided or +nil+
    #               if the format is not supported/known.
    def self.contentTypeFor(formatSym)
      return FORMATS2CONTENT_TYPE[formatSym]
    end

    # ##########################################################################
    # HELPERS
    # ##########################################################################

    # Special generic method to create instance from parsed JSON result (or parsed YAML,
    # XML or other, as long as the data structure from the parsing is the same for those formats too)
    # when there's a list of simple field names that are assigned values in +SIMPLE_FIELD_NAMES+.
    #
    # Because of default values in the constructors and because simple fields are listed first
    # in the constructors, the object can be instantiated from parsed JSON (or whatever) via this method,
    # and then the calling method can add the more complex data structures to the resulting object if
    # needed. So even for complex cases, this helper is useful for handling the simple fields.
    #
    # Generally no need to override. Just use this as needed.
    #
    # [+parsedJsonResult+]  Object that resulted from <tt>JSON.parse()</tt> on a JSON string or a compatible
    #                       data structure resulting from parsing XML, YAML, etc.
    # [+fieldNames+]        [optional; default=+SIMPLE_FIELD_NAMES+] A list names of simple fields, in order matching constructor argument order.
    # [+returns+]           Instance of this class or +nil+ if +parsedJsonResult+ appears bad.
    def self.jsonCreateSimple(parsedJsonResult, fieldNames=self::SIMPLE_FIELD_NAMES)
      retVal = nil
      # Get content and status info from Common Wrapper if present. If not, content will be parsedJsonResult
      content = AbstractEntity.extractParsedContent(parsedJsonResult)
      status = AbstractEntity.extractParsedStatus(parsedJsonResult)
      # For each field, extract its value from the parsed JSON object and add it to constructor arguments.
      args = []
      fieldNames.each_index { |ii|
        fieldName = fieldNames[ii]
        defaultValue = ((self::SIMPLE_FIELD_VALUES.empty? or self::SIMPLE_FIELD_VALUES.size <= ii) ? nil : self::SIMPLE_FIELD_VALUES[ii])
        if(content.is_a?(Hash) and content.key?(fieldName))
          value = content[fieldName]
          args << value
        elsif(defaultValue or defaultValue == false) # then we have a default value (including exactly false) we can use that if not provided
          value = defaultValue
          args << defaultValue
        else # expected field is missing and we have no default!
          #raise "Expecting '#{fieldName}' in representation, but not found."
          $stderr.debugPuts(__FILE__, __method__, "ERROR", "Expecting '#{fieldName}' in representation, but not found.")
          retVal = :'Unsupported Media Type'
          args = nil
          break
        end
      }
      # If everything went ok and we found everything, then args is filled with values; otherwise args is nil & there were problems.
      unless(args.nil?)
        doRefs = content.key?("refs")
        retVal = self.new(doRefs, *args) # Call new() for whatever class this method is in (through inheritance)
        # Some entities have a "refs" field. Add now if present.
        retVal.refs = content["refs"] if(doRefs)
        # Set status info from parsedJsonResult, unless data wasn't wrapped in Common Wrapper
        # or status key set to nil or something, in which case default status is used.
        retVal.setStatus(status["statusCode"], status["msg"]) unless(status.nil?)
      end
      return retVal
    end

    # Helper method that creates a representation of an error rather than of data.
    # Generally no need to override at all, just use this to have the status and message
    # properly wrapped in an entity that can be formatted according to the request so that
    # the requestor can parse and process the error response.
    # [+repFormat+]   What is the format of the error representation? One of <tt>:JSON</tt>,
    #                 <tt>:YAML</tt>, <tt>:XML</tt> or <tt>:LFF</tt>.
    # [+statusName+]  The name of the HTTP response status, as a +Symbol+.
    # [+statusMsg+]   A +String+ with an explanation of what was wrong, using specifics to aid the requestor/developer
    #                 and generally starting with a single-word "tag" that can be used to quickly ID specific types of
    #                 Genboree API errors that can come up (but that the HTTP response code is too general for.)
    # [+returns+]     A +String+ containing the formatted err.
    def self.representError(repFormat, statusName, statusMsg)
      entity = BRL::Genboree::REST::Data::AbstractEntity.new(false, true, statusName, statusMsg)
      entity.resourceType = :ERROR
      body =  if(repFormat == :YAML)
                entity.to_yaml()
              elsif(repFormat == :XML)
                entity.xmlRoot = :ERROR
                entity.to_xml()
              elsif(repFormat == :LFF)
                "#{statusName}\t#{statusMsg}"
              elsif(repFormat == :JSON_PRETTY)
                entity.to_jsonPretty()
              else # default to compact JSON
                entity.to_json()
              end
      return body
    end

    # Helper method to look inside the envelope/wrapper and extract just the data object from a parsed result.
    # This method assumes the argument itself _is_ the data object if the argument is not a +Hash+ or
    # doesn't contain the hash key "data"--this is useful in that it handles unwrapped data (LFF, etc) or
    # data that's already been extracted without causing problems.
    # [+parsedJsonResult+]  Object resulting from parsing a serialized object. Doesn't actually have to be
    #                       from parsing JSON.
    # [+returns+]           Data-only object (no envelope/wrapper); if +parsedJsonResult+ doesn't seem to have the envelope
    #                       then just return +parsedJsonResult+ (i.e. assume it -is- the data already)
    def self.extractParsedContent(parsedJsonResult)
      retVal =  if(parsedJsonResult.is_a?(Hash) and parsedJsonResult.key?("data"))
                  parsedJsonResult["data"]
                else
                  parsedJsonResult
                end
      return retVal
    end

    # Helper method to look inside the envelope/wrapper and extract just the status object from a parsed result.
    # This method assumes the argument itself _is_ the data object if the argument is not a +Hash+ or
    # doesn't contain the hash key "status"--this is useful in that it handles unwrapped data (LFF, etc) or
    # status that's already been extracted without causing problems.
    # [+parsedJsonResult+]  Object resulting from parsing a serialized object. Doesn't actually have to be
    #                       from parsing JSON.
    # [+returns+]           Status-only object (no data); if +parsedJsonResult+ doesn't seem to have the envelope
    #                       then just return +parsedJsonResult+ (i.e. assume it -is- the status already)
    def self.extractParsedStatus(parsedJsonResult)
      retVal =  if(parsedJsonResult.is_a?(Hash) and parsedJsonResult.key?("status"))
                  parsedJsonResult["status"]
                else
                  nil
                end
      return retVal
    end
  end # class AbstractEntity

  # --------------------------------------------------------------------------
  # EntityList
  # - Abstract class for Arrays of Genboree AbstractEntity objects.
  # - Will behave like an array (thanks to method_missing & delegation) but
  #   also will properly wrap the array in common Genboree envelope and also
  #   knows how to properly convert member objects to JSON.
  # Common Interface Methods:
  #   . to_json(), to_yaml(), to_xml()        <-- default implementations from parent class
  #   . from_json()                           <-- OVERRIDDEN
  #   . AbstractEntity.from_yaml(), AbstractEntity.from_xml()               <-- default implementations from parent class
  #   . getFormatableDataStruct()             <-- OVERRIDDEN
  # --------------------------------------------------------------------------

  # == Purpose: Abstract Genboree Resource _Representation_ class for _collections_ (lists) of entities.
  # This largely abstract class provides default implementations of core required methods
  # for any data representation class used by the API. Unlike +AbstractEntity+, the default
  # implementation here often provides almost all of what a specific entity-list subclass will need.
  #
  # Only a minimal subclass implementation is generally required needed.
  #
  # Note that this class inherits from +AbstractEntity+ and thus benefits from all the privileges,
  # instance variables, methods, and duties thereof.
  #
  # == Overview
  # All Genboree API representation list subclasses inherit from this this class.
  #
  # The default/core implementations here are generally multi-format aware and support generation of JSON, YAML,
  # and XML variants of the representation as long as conventions are followed.
  #
  # Because the implementations here handle a lot of the necessary work, subclasses only
  # need to implement small amounts of additional code or override just a handful of methods
  # for their specific representations.
  #
  # === Class Constants Subclasses must provide
  # In addition to the 3 class constants described in +AbstractEntity+, subclasses must set the following
  # class constants which the API server framework will use to determine how to use the list to contain a
  # collection of individual entities:
  # [+ELEMENT_CLASS+]  The class of the entities stored within this list/collection.
  #
  # === Common Instance Variables
  # In addition to the key instance variables provided by +AbstractEntity+, collection representations
  # additionally contain a couple extra attributes.
  #
  # * <em><b>Refer to the attributes documented for this class to see what is available</b></em>
  #
  # === Common Interface Method Notes
  # Almost all the serialization/deserialization and most of the handling of parsed XML & YAML
  # are handled by the default methods inherited from +AbstractEntity+--no need to reimplement
  # them here. A couple of the JSON methods are overridden here, but are then reused by the
  # inherited methods to implement XML and YAML support.
  #
  # Note that this class implements #method_missing and the default implementation sends any
  # methods it doesn't know about to the actually @array of individual entity data structures.
  # Such as @size or #[] for example. If you need a slightly different behavior (most
  # subclasses don't), override that method.
  #
  # DO NOT USE THIS CLASS TO STORE BASIC RUBY TYPES (e.g. String, Hash, Array, Fixnum, Float, boolean).
  # - it is meant to store AbstractEntity subclass objects.
  class EntityList < AbstractEntity

    # A +Symbol+ naming the resource with a code-friendly (ok, XML tag-name friendly) name. This is currently used in
    # generating XML for _lists_...they will be lists of tags of this type (XML makes it hard to express certain natural things easily...)
    RESOURCE_TYPE = :EntityList

    # @return [String] The key for the reference url (when connect=yes)
    # @todo remove this and use JSON-LD @ref approach
    REFS_KEY = "#{RESOURCE_TYPE}_#{FORMATS.join('.')}"

    # The class of the individual entities within this collection. Subclasses always override this.
    ELEMENT_CLASS = AbstractEntity

    # Some entity List have the format {'data'=>[entities]}
    # and others use the format {'data'=>{'someFieldName'=>[entities]}}
    # use LIST_FIELD to define the field name that contains the entity list if required
    LIST_FIELD = nil

    # An +Array+ of individual data structures corresponding to the individual entities within the collection
    # The framework will assume this is present so it can convert and represent the collection appropriately.
    attr_accessor :array
    # The class of the individual entities with this collection (framework sets this to +ELEMENT_CLASS+, but can be
    # programmatically manipulated with this attribute if needed.)
    attr_accessor :elementClass

    # Constuctor. Matching GENBOREE INTERFACE.
    # [+doRefs+]      [optional; default=true] Do you want the "refs" field in any representation of this entity (i.e. make connections or save size/complexity of representation?)
    # [+array+]       [optional; default=[]] +Array+ of individual data structures going into this collection. They can be added later if not provided to the constructor.
    def initialize(doRefs=true, array=[])
      super(doRefs)
      self.update(array)
    end

    def acts_as?(aClass)
      return @array.acts_as?(aClass)
    end

    # REUSE INSTANCE. Update this instance with new data; supports reuse of instances rather than always making new objects.
    # Replaces the current array of data with the ones in the +array+ argument.
    # For overriding by subclasses needing more sophisticated implementations, this default implementation
    # can handle additional arguments (they go into +args+ but will be ignored).
    # [+array+]   +Array+ of individual data structures going into this collection. They can be added later if not provided to the constructor.
    # [+args+]    Any additional args provided are slurped up in this +Array+
    # [+returns+] This Class.
    def update(array, *args)
      @array.clear unless(@array.nil?)
      array = [] if(array.nil?)
      @array = array
      @elementClass = self.class::ELEMENT_CLASS
    end

    # GENBOREE INTERFACE. Import (add) individual entities into this list from *raw data*.
    # For each object in "array" arg, an new instance of this classes' ELEMENT_CLASS will
    # be created and added to the list. Mainly a convenience method to save typing everywhere.
    # - doRefs for each item will mimic @doRefs for this instance
    def importFromRawData(array)
      array.each { |item|
        itemEntityObj = self.class::ELEMENT_CLASS.new((@refs ? true : false), item)
        @array << itemEntityObj
      }
      return @array
    end

    # GENBOREE INTERFACE. Get a +Hash+ or +Array+ that represents this entity.
    # The default implementation will simply wrap @array, which means it's
    # fine for most subclasses, as long as @array is being sensibly maintained.
    # [+returns+] A +Hash+ or +Array+ representing this entity (or collection of entities)
    #             wrapped in the standardized Genboree wrapper, if appropriate.
    #             _Entity class specific_
    def getFormatableDataStruct()
      @array.each { |obj| obj.doWrap = false } # these objects are within an Array, they should NOT each be wrapped
      retVal = self.wrap(@array)
      return retVal
    end

    # @api RestDataEntity
    # GENBOREE INTERFACE. Subclasses inherit; override for subclasses that generate
    # complex data representations. Generally don't need to override if there is also
    # an ELEMENT_CLASS class implemented and this EntityList subclass is just a collection
    # of AbstractEntity subclass objects (which thus would each need their toStructuredData()
    # called).
    #
    # Get a {Hash} or {Array} that represents this entity.
    # Generally used to convert to some String format for serialization. Especially to JSON.
    # @note Must ONLY use Ruby primitives (String, Fixnum, Float, booleans) or
    #   basic Ruby collections (Hash, Array). No custom classes.
    # @param [Boolean] wrap Indicating whether the standard Genboree wrapper should be used to
    #   contain the representation or not. Generally true, except when the representation is
    #   within a parent representation [which is likely wrapped].
    # @return [Hash,Array] representing this entity (or collection of entities)
    #   wrapped in the standardized Genboree wrapper, if appropriate.
    def toStructuredData(wrap=@doWrap)
      data = Array.new(@array.size)
      @array.each_index { |ii|
        val = @array[ii]
        if(val.respond_to?(:toStructuredData)) # then val is an AbstractEntity object
          data[ii] = val.toStructuredData(false)
        else # val is a basic type (String, Float, Fixnum, boolean, Hash, Array,etc), add directly
          data[ii] = val
        end
      }
      if(wrap)
        retVal = self.wrap(data) # Wrap the data content in standard Genboree JSON envelope
      else
        retVal = data
      end
      return retVal
    end

    # JSON INTERFACE: Implement a standard AbstractEntity.from_json method to parse a JSON
    # representation. This is overridden here to loop into the +Array+ of entities
    # and create instances of their data representation classes, adding each to the collection.
    # Generally, subclasses don't need to override this if they have a straight-forward
    # entity collection; if they have some extra fields (not just array of entities) then
    # they'll need to override this.
    # [+parsedJsonResult+]  The +Hash+ or +Array+ resulting from parsing the JSON string.
    # [+returns+]           Instance of this class, whose state comes from data within +parsedJsonResult+.
    def self.from_json(parsedJsonResult)
      # Get content and status info from Common Wrapper if present...ff not, content will be parsedJsonResult
      content = AbstractEntity.extractParsedContent(parsedJsonResult)
      status = AbstractEntity.extractParsedStatus(parsedJsonResult)
      # Create entity based on content, if content is looks correct. Else empty.
      array = []
      # Some entity List have the format {'data'=>[entities]}
      # and others use the format {'data'=>{'someFieldName'=>[entities]}}
      # use LIST_FIELD to define the field name that contains the entity list if required
      contentList = (!self::LIST_FIELD.nil?) ? content[self::LIST_FIELD] : content
      # Quick check: at this point contentList MUST be an Array which we can iterate over to create
      # the member objects. If it's not an Array, return :'Unsupported Media Type' rather than trying further (and failing)
      if(contentList.is_a?(Array))
        contentList.each { |obj| # For each object in the array, convert it to an entity
          entity = self::ELEMENT_CLASS.from_json(obj)
          array << entity unless(entity.nil?)
        }
        doRefs = (contentList.respond_to?(:'key?') and contentList.key?("refs"))
        if(!self::SIMPLE_FIELD_NAMES.empty?) # Support Entity lists objects that have more fields
          fieldNames = self::SIMPLE_FIELD_NAMES
          args = []
          fieldNames.each_index { |ii|
            fieldName = fieldNames[ii]
            defaultValue = ((self::SIMPLE_FIELD_VALUES.empty? or self::SIMPLE_FIELD_VALUES.size <= ii) ? nil : self::SIMPLE_FIELD_VALUES[ii])
            if(content.key?(fieldName))
              value = content[fieldName]
              args << value
            elsif(defaultValue) # then we have a default value we can use if not provided
               value = defaultValue
               args << defaultValue
            else # expected field is missing and we have no default!
              raise "Expecting '#{fieldName}' in representation, but not found."
            end
          }
          # If everything went ok and we found everything, then args is filled with values; otherwise args is nil & there were problems.
          unless(args.nil?)
            doRefs = content.key?("refs")
            retVal = self.new(doRefs, *args) # Call new() for whatever class this method is in (through inheritance)
            # Some entities have a "refs" field. Add now if present.
            retVal.refs = content["refs"] if(doRefs)
            # Set status info from parsedJsonResult, unless data wasn't wrapped in Common Wrapper
            # or status key set to nil or something, in which case default status is used.
            retVal.setStatus(status["statusCode"], status["msg"]) unless(status.nil?)
          end
        else # Entity List object only contains an array of Entities
          retVal = self.new(doRefs, array)
          # Set status info from parsedJsonResult, unless data wasn't wrapped in Common Wrapper
          # or status key set to nil or something, in which case default status is used.
          retVal.setStatus(status["statusCode"], status["msg"]) unless(status.nil?)
        end
      else # data content of payload not an Array, can't from_json()
        return :'Unsupported Media Type'
      end
      return retVal
    end

    def self.from_jsonPretty(parsedJsonResult)
      return self.from_json(parsedJsonResult)
    end

    # JSON INTERFACE: Implement a standard AbstractEntity.json_create method.
    # This class method defined by the JSON library allows instances of this class
    # to be created from -parsed- JSON (i.e. a +Hash+ or +Array+ resulting from JSON::parse).
    # The default implementation just calls AbstractEntity.from_json which is likely fine for almost all subclasses.
    # [+parsedJsonResult+]  The +Hash+ or +Array+ resulting from parsing the JSON string.
    # [+returns+]           Instance of this class, whose state comes from data within +parsedJsonResult+.
    def self.json_create(parsedJsonResult)
      return self.from_json(parsedJsonResult)
    end

    # Delegate all other methods to @array (eg <<, +, +length+, +each+, etc). This is
    # a standard Ruby method available to all objects. This delegation to @array is kind a like having this class inherit from Array also.
    # NOTE: the array stores specific types of objects, generally some sort of *Entity class.
    # All array inputs are assumed to be instances of the appropriate class.
    # [+meth+]    The name of the method as a +Symbol+ or +String+.
    # [+args+]    All the arguments to the method will be slurped up into this local variable.
    # [+block+]   If there's a code block provided (e.g. for +each+), it will be here.
    def method_missing(meth, *args, &block)
      @array.send(meth, *args, &block)
    end

    alias :'old_respond_to?' :'respond_to?'
    def respond_to?(arg)
      #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "arg: #{arg.inspect}")
      retVal = old_respond_to?(arg)
      #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "retVal #{retVal.inspect}")
      # try hashMap if this class itself doesn't respond
      #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "@hashMap: #{@hashMap.inspect}")
      retVal = @hashMap.respond_to?(arg) unless(retVal)
      return retVal
    end
  end # class EntityList < BRL::Genboree::REST::Data::AbstractEntity

  # --------------------------------------------------------------------------
  # EntityHash
  # - Abstract class for Hashes of Genboree AbstractEntity objects.
  # - Will behave like a Hash (thanks to method_missing & delegation), typically with Strings as keys but
  #   also will properly wrap the HASH in common Genboree envelope and also
  #   knows how to properly convert member objects to JSON.
  # Common Interface Methods:
  #   . to_json(), to_yaml(), to_xml()        <-- default implementations from parent class
  #   . from_json()                           <-- OVERRIDDEN
  #   . AbstractEntity.from_yaml(), AbstractEntity.from_xml()               <-- default implementations from parent class
  #   . getFormatableDataStruct()             <-- OVERRIDDEN
  # --------------------------------------------------------------------------

  # == Purpose: Abstract Genboree Resource _Representation_ class for _collections_ (hashes) of entities.
  # This largely abstract class provides default implementations of core required methods
  # for any data representation class used by the API. Unlike +AbstractEntity+, the default
  # implementation here often provides almost all of what a specific entity-hash subclass will need.
  #
  # Only a minimal subclass implementation is generally required needed.
  #
  # Note that this class inherits from +AbstractEntity+ and thus benefits from all the privileges,
  # instance variables, methods, and duties thereof.
  #
  # == Overview
  # All Genboree API representation list subclasses inherit from this this class.
  #
  # The default/core implementations here are generally multi-format aware and support generation of JSON, YAML,
  # and XML variants of the representation as long as conventions are followed.
  #
  # Because the implementations here handle a lot of the necessary work, subclasses only
  # need to implement small amounts of additional code or override just a handful of methods
  # for their specific representations.
  #
  # === Class Constants Subclasses must provide
  # In addition to the 3 class constants described in +AbstractEntity+, subclasses must set the following
  # class constants which the API server framework will use to determine how to use the list to contain a
  # collection of individual entities:
  # [+ELEMENT_CLASS+]  The class of the entities stored within this list/collection.
  #
  # === Common Instance Variables
  # In addition to the key instance variables provided by +AbstractEntity+, collection representations
  # additionally contain a couple extra attributes.
  #
  # * <em><b>Refer to the attributes documented for this class to see what is available</b></em>
  #
  # === Common Interface Method Notes
  # Almost all the serialization/deserialization and most of the handling of parsed XML & YAML
  # are handled by the default methods inherited from +AbstractEntity+--no need to reimplement
  # them here. A couple of the JSON methods are overridden here, but are then reused by the
  # inherited methods to implement XML and YAML support.
  #
  # Note that this class implements #method_missing and the default implementation sends any
  # methods it doesn't know about to the actually @array of individual entity data structures.
  # Such as @size or #[] for example. If you need a slightly different behavior (most
  # subclasses don't), override that method.
  #
  # DO NOT USE THIS CLASS TO STORE BASIC RUBY TYPES (e.g. String, Hash, Array, Fixnum, Float, boolean).
  # - it is meant to store AbstractEntity subclass objects.
  class EntityHash < AbstractEntity

    # A +Symbol+ naming the resource with a code-friendly (ok, XML tag-name friendly) name. This is currently used in
    # generating XML for _hashes_...they will be hashes of tags of this type (XML makes it hard to express certain natural things easily...)
    RESOURCE_TYPE = :EntityHash

    # @return [String] The key for the reference url (when connect=yes)
    # @todo remove this and use JSON-LD @ref approach
    REFS_KEY = "#{RESOURCE_TYPE}_#{FORMATS.join('.')}"

    # The class of the individual entities within this collection. Subclasses always override this.
    ELEMENT_CLASS = AbstractEntity

    # Some entity List have the format {'data'=>{entitiesHash}}
    # and others use the format {'data'=>{'someFieldName'=>{entities}}}
    # (i.e. if there are extra info fields in addition to the hashMap)
    # use HASH_FIELD to define the field name that contains the entity hashMap if required
    HASH_FIELD = nil

    # An +Array+ of individual data structures corresponding to the individual entities within the collection
    # The framework will assume this is present so it can convert and represent the collection appropriately.
    attr_accessor :hashMap
    # The class of the individual entities with this collection (framework sets this to +ELEMENT_CLASS+, but can be
    # programmatically manipulated with this attribute if needed.)
    attr_accessor :elementClass

    # Constuctor. Matching GENBOREE INTERFACE.
    # [+doRefs+]      [optional; default=true] Do you want the "refs" field in any representation of this entity (i.e. make connections or save size/complexity of representation?)
    # [+hashMap+]     [optional; default={}] +Hash+ of individual data structures going into this collection. They can be added later if not provided to the constructor.
    def initialize(doRefs=true, hashMap={})
      super(doRefs)
      self.update(hashMap)
    end

    def acts_as?(aClass)
      return @hashMap.acts_as?(aClass)
    end

    # REUSE INSTANCE. Update this instance with new data; supports reuse of instances rather than always making new objects.
    # Replaces the current hashMap of data with the ones in the +hashMap+ argument.
    # For overriding by subclasses needing more sophisticated implementations, this default implementation
    # can handle additional arguments (they go into +args+ but will be ignored).
    # [+hashMap+]   +Hash+ of individual data structures going into this collection. They can be added later if not provided to the constructor.
    # [+args+]    Any additional args provided are slurped up in this +Array+
    # [+returns+] This Class.
    def update(hashMap, *args)
      @hashMap.clear unless(@hashMap.nil?)
      hashMap = {} if(hashMap.nil?)
      @hashMap = hashMap
      @elementClass = self.class::ELEMENT_CLASS
    end

    # GENBOREE INTERFACE. Import (add) individual entities into this list from *raw data*.
    # For each object in "array" arg, an new instance of this classes' ELEMENT_CLASS will
    # be created and added to the list. Mainly a convenience method to save typing everywhere.
    # - doRefs for each item will mimic @doRefs for this instance
    def importFromRawData(hashMap)
      hashMap.each_key { |key|
        item = hashMap[key]
        itemEntityObj = self.class::ELEMENT_CLASS.new((@refs ? true : false), item)
        @hashMap[key] = itemEntityObj
      }
      return @hashMap
    end

    # GENBOREE INTERFACE. Get a +Hash+ or +Array+ that represents this entity.
    # The default implementation will simply wrap @array, which means it's
    # fine for most subclasses, as long as @array is being sensibly maintained.
    # [+returns+] A +Hash+ or +Array+ representing this entity (or collection of entities)
    #             wrapped in the standardized Genboree wrapper, if appropriate.
    #             _Entity class specific_
    def getFormatableDataStruct()
      @hashMap.each_key { |key|
        obj = @hashMap[key]
        if(obj.respond_to?(:doWrap))
          obj.doWrap = false
        end
      } # these objects are within an Array, they should NOT each be wrapped
      retVal = self.wrap(@hashMap)
      return retVal
    end

    # @api RestDataEntity
    # GENBOREE INTERFACE. Subclasses inherit; override for subclasses that generate
    # complex data representations. Generally don't need to override if there is also
    # an ELEMENT_CLASS class implemented and this EntityList subclass is just a collection
    # of AbstractEntity subclass objects (which thus would each need their toStructuredData()
    # called)
    #
    # Get a {Hash} or {Array} that represents this entity.
    # Generally used to convert to some String format for serialization. Especially to JSON.
    # @note Must ONLY use Ruby primitives (String, Fixnum, Float, booleans) or
    #   basic Ruby collections (Hash, Array). No custom classes.
    # @param [Boolean] wrap Indicating whether the standard Genboree wrapper should be used to
    #   contain the representation or not. Generally true, except when the representation is
    #   within a parent representation [which is likely wrapped].
    # @return [Hash,Array] representing this entity (or collection of entities)
    #   wrapped in the standardized Genboree wrapper, if appropriate.
    def toStructuredData(wrap=@doWrap)
      data = {}
      @hashMap.each_key { |kk|
        val = @hashMap[kk]
        if(val.respond_to?(:toStructuredData)) # then val is an AbstractEntity object
          data[kk] = val.toStructuredData(false)
        else # val is a simple type (String, Float, Fixnum, boolean, etc), add directly
          data[kk] = val
        end
      }
      if(wrap)
        retVal = self.wrap(data) # Wrap the data content in standard Genboree JSON envelope
      else
        retVal = data
      end
      return retVal
    end

    # JSON INTERFACE: Implement a standard AbstractEntity.from_json method to parse a JSON
    # representation. This is overridden here to loop into the +Hash+ of entities
    # and create instances of their data representation classes, adding each to the collection.
    # Generally, subclasses don't need to override this if they have a straight-forward
    # entity collection; if they have some extra fields (not just hashMap of entities) then
    # they'll need to override this.
    # [+parsedJsonResult+]  The +Hash+ or +Array+ resulting from parsing the JSON string.
    # [+returns+]           Instance of this class, whose state comes from data within +parsedJsonResult+.
    def self.from_json(parsedJsonResult)
      # Get content and status info from Common Wrapper if present...ff not, content will be parsedJsonResult
      content = AbstractEntity.extractParsedContent(parsedJsonResult)
      status = AbstractEntity.extractParsedStatus(parsedJsonResult)
      # Create entity based on content, if content is looks correct. Else empty.
      hashMap = {}
      # Some entity Hashes have the format {'data'=>{entitiesHash}}
      # and others use the format {'data'=>{'someFieldName'=>{entitiesHash}}}
      # (i.e. if there are extra info fields in addition to the hashMap)
      # use HASH_FIELD to define the field name that contains the entity list if required
      contentHash = (!self::HASH_FIELD.nil?) ? content[self::HASH_FIELD] : content
      contentHash.each_key { |key|
        obj = contentHash[key] # For each object in the hash, convert it to an entity
        entity = self::ELEMENT_CLASS.from_json(obj)
        hashMap[key] = entity unless(entity.nil?)
      }
      doRefs = (contentHash.respond_to?(:'key?') and contentHash.key?("refs"))
      if(!self::SIMPLE_FIELD_NAMES.empty?) # Support Entity lists objects that have more fields
        fieldNames = self::SIMPLE_FIELD_NAMES
        args = []
        fieldNames.each_index { |ii|
          fieldName = fieldNames[ii]
          defaultValue = ((self::SIMPLE_FIELD_VALUES.empty? or self::SIMPLE_FIELD_VALUES.size <= ii) ? nil : self::SIMPLE_FIELD_VALUES[ii])
          if(content.key?(fieldName))
            value = content[fieldName]
            args << value
          elsif(defaultValue) # then we have a default value we can use if not provided
             value = defaultValue
             args << defaultValue
          else # expected field is missing and we have no default!
            raise "Expecting '#{fieldName}' in representation, but not found."
          end
        }
        # If everything went ok and we found everything, then args is filled with values; otherwise args is nil & there were problems.
        unless(args.nil?)
          doRefs = content.key?("refs")
          retVal = self.new(doRefs, *args) # Call new() for whatever class this method is in (through inheritance)
          # Some entities have a "refs" field. Add now if present.
          retVal.refs = content["refs"] if(doRefs)
          # Set status info from parsedJsonResult, unless data wasn't wrapped in Common Wrapper
          # or status key set to nil or something, in which case default status is used.
          retVal.setStatus(status["statusCode"], status["msg"]) unless(status.nil?)
        end
      else # Entity Hash object only contains an array of Entities
        retVal = self.new(doRefs, array)
        # Set status info from parsedJsonResult, unless data wasn't wrapped in Common Wrapper
        # or status key set to nil or something, in which case default status is used.
        retVal.setStatus(status["statusCode"], status["msg"]) unless(status.nil?)
      end
      return retVal
    end

    def self.from_jsonPretty(parsedJsonResult)
      return self.from_json(parsedJsonResult)
    end

    # JSON INTERFACE: Implement a standard AbstractEntity.json_create method.
    # This class method defined by the JSON library allows instances of this class
    # to be created from -parsed- JSON (i.e. a +Hash+ or +Array+ resulting from JSON::parse).
    # The default implementation just calls AbstractEntity.from_json which is likely fine for almost all subclasses.
    # [+parsedJsonResult+]  The +Hash+ or +Array+ resulting from parsing the JSON string.
    # [+returns+]           Instance of this class, whose state comes from data within +parsedJsonResult+.
    def self.json_create(parsedJsonResult)
      return self.from_json(parsedJsonResult)
    end

    # Delegate all other methods to @hashMap (eg [], +, +length+, +each_key+, etc). This is
    # a standard Ruby method available to all objects. This delegation to @hashMap is kind a like having this class inherit from Hash also.
    # NOTE: the hash stores specific types of objects, generally some sort of *Entity class.
    # All hash values are assumed to be instances of the appropriate class.
    # [+meth+]    The name of the method as a +Symbol+ or +String+.
    # [+args+]    All the arguments to the method will be slurped up into this local variable.
    # [+block+]   If there's a code block provided (e.g. for +each+), it will be here.
    def method_missing(meth, *args, &block)
      @hashMap.send(meth, *args, &block)
    end

    alias :'old_respond_to?' :'respond_to?'
    def respond_to?(arg)
      retVal = old_respond_to?(arg)
      # try hashMap if this class itself doesn't respond
      retVal = @hashMap.respond_to?(arg) unless(retVal)
      return retVal
    end
  end # class EntityHash < BRL::Genboree::REST::Data::AbstractEntity
end ; end ; end ; end # module BRL ; module Genboree ; module REST ; module Data
