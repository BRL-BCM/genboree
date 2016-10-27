#!/usr/bin/env ruby
require 'brl/genboree/rest/data/entity'

module BRL ; module Genboree ; module REST ; module Data

  # HostRecordEntity - Representation of a host access info for a Genboree user.
  # - Currently used for accessing REMOTE Genboree instances.
  # TODO: make token the SHA1(login,password) not raw password like it is now. Coord change with storing this token in DB rather than raw passwords.
  #
  # Common Interface Methods:
  # - #to_json, #to_yaml, #to_xml        -- default implementations from parent class
  # - AbstractEntity.from_json, AbstractEntity.from_yaml, AbstractEntity.from_xml  -- default implementations from parent class
  # - #getFormatableDataStruct           -- OVERRIDDEN
  class HostRecordEntity < BRL::Genboree::REST::Data::AbstractEntity
    # What formats are supported, using the conventional +Symbols+. Subclasses may or may not override this.
    FORMATS = [ :JSON, :JSON_PRETTY, :XML, :YAML ]
    # A +Symbol+ naming the resource with a code-friendly (ok, XML tag-name friendly) name. This is currently used in
    # generating XML for _lists_...they will be lists of tags of this type (XML makes it hard to express certain natural things easily...)
    RESOURCE_TYPE = :HostRecord

    # @return [String] The key for the reference url (when connect=yes)
    # @todo remove this and use JSON-LD @ref approach
    REFS_KEY = "#{RESOURCE_TYPE}_#{FORMATS.join('.')}"

    # Any basic name-value type fields; i.e. where the value is not a complex data structure but rather some text or a number.
    # Framework will do some automatic processing and presentation of those for you. Subclasses will override this, obviously.
    SIMPLE_FIELD_NAMES = [ "host", "login", "token" ]

    # The login name of the user.
    attr_accessor :login
    # Remote host domain name
    attr_accessor :host
    # User's 'token' at remote host. # TODO: make token the SHA1(login,password) not raw password like it is now. Coord change with storing this token in DB rather than raw passwords.
    attr_accessor :token

    # CONSTRUCTOR.
    # [+doRefs+] [optional; default=true] Do you want the "refs" field in any representation of this entity (i.e. make connections or save size/complexity of representation?)
    # [+host+] [optional; default=""]  The domain name of the remote Genboree host
    # [+login+] [optional; default=""] The login name of the user.
    # [+token+] [optional; default=""] User password at remote host.  # TODO: make token the SHA1(login,password) not raw password like it is now. Coord change with storing this token in DB rather than raw passwords.
    def initialize(doRefs=true, host="", login="", token="")
      super(doRefs)
      self.update(host, login, token)
    end

    # REUSE INSTANCE. Update this instance with new data; supports reuse of instances rather than always making new objects
    # [+host+] [optional; default=""]  The domain name of the remote Genboree host
    # [+login+] [optional; default=""] The login name of the user.
    # [+token+] [optional; default=""] User password at remote host.  # TODO: make token the SHA1(login,password) not raw password like it is now. Coord change with storing this token in DB rather than raw passwords.
    def update(host, login, token)
      @refs.clear() if(@refs)
      @host, @login, @token = host, login, token
    end

    # GENBOREE INTERFACE. Get a +Hash+ or +Array+ that represents this entity.
    # - used by the default implementations of <tt>to_*()</tt> methods
    # - override in sub-classes
    # - this data structure will be used in the serialization implementations
    # [+returns+] A +Hash+ or +Array+ representing this entity (or collection of entities)
    #             wrapped in the standardized Genboree wrapper, if appropriate.
    #             <i>Entity class specific</i>
    def getFormatableDataStruct()
      data =  {
                "host"  => @host,
                "login" => @login,
                "token" => @token
              }
      data['refs'] = @refs if(@refs)
      retVal = self.wrap(data)  # Wrap the data content in standard Genboree JSON envelope
      return retVal
    end

    # @api RestDataEntity
    # GENBOREE INTERFACE. Subclasses inherit; override for subclasses that generate
    # complex data representations mainly for speed (i.e. to avoid the reflection methods).
    # Inherited version works by using SIMPLE_FIELD_NAMES and reflection methods; even if you
    # just need the stuff in SIMPLE_FIELD_NAMES and don't have fields with complex data structures
    # in the representation, overriding to NOT use the reflection stuff will be faster [a little].
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
      # The SIMPLE_FIELD_NAMES first. Values are basic Ruby types (String, Hash, Array, Fixnum, Float, boolean, etc)
      data =
      {
        "host"  => @host,
        "login" => @login,
        "token" => @token
      }
      data['refs'] = @refs if(@refs)
      retVal = (wrap ? self.wrap(data) : data)
      return retVal
    end
  end # class HostRecordEntity < BRL::Genboree::REST::Data::AbstractEntity
end ; end ; end ; end  # module BRL ; module Genboree ; module REST ; module Data
