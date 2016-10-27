#!/usr/bin/env ruby
require 'brl/genboree/rest/data/entity'

module BRL ; module Genboree ; module REST ; module Data

  # FullUserEntity - Representation of a Genboree user: its login, name info, location/contact info, etc.
  # This level of info should really only be available to the superuser.
  #
  # Common Interface Methods:
  # - #to_json, #to_yaml, #to_xml        -- default implementations from parent class
  # - AbstractEntity.from_json, AbstractEntity.from_yaml, AbstractEntity.from_xml  -- default implementations from parent class
  # - #getFormatableDataStruct           -- OVERRIDDEN
  class FullUserEntity < BRL::Genboree::REST::Data::AbstractEntity
    # What formats are supported, using the conventional +Symbols+. Subclasses may or may not override this.
    FORMATS = [ :JSON, :XML, :YAML ]
    # A +Symbol+ naming the resource with a code-friendly (ok, XML tag-name friendly) name. This is currently used in
    # generating XML for _lists_...they will be lists of tags of this type (XML makes it hard to express certain natural things easily...)
    RESOURCE_TYPE = :UsrFull

    # @return [String] The key for the reference url (when connect=yes)
    # @todo remove this and use JSON-LD @ref approach
    REFS_KEY = "#{RESOURCE_TYPE}_#{FORMATS.join('.')}"

    # Any basic name-value type fields; i.e. where the value is not a complex data structure but rather some text or a number.
    # Framework will do some automatic processing and presentation of those for you. Subclasses will override this, obviously.
    SIMPLE_FIELD_NAMES = [ "login", "firstName", "lastName", "institution", "telephone", "email", "password" ]

    # The login name of the user.
    attr_accessor :login
    # User's "first" name.
    attr_accessor :firstName
    # User's last name.
    attr_accessor :lastName
    # Institution the user is at, if any
    attr_accessor :institution
    # User's phone number if any
    attr_accessor :telephone
    # User's email.
    attr_accessor :email
    # User's password !!!
    attr_accessor :password

    # CONSTRUCTOR.
    # [+doRefs+] [optional; default=true] Do you want the "refs" field in any representation of this entity (i.e. make connections or save size/complexity of representation?)
    # [+login+] [optional; default=""] The login name of the user.
    # [+firstName+] [optional; default=""] User's "first" name.
    # [+lastName+] [optional; default=""] User's last name.
    # [+institution+] [optional; default=""] Institution the user is at, if any.
    # [+telephone+] [optional; default=""] User's phone number if any.
    # [+email+] [optional; default=""] User's email.
    def initialize(doRefs=true, login="", firstName="", lastName="", institution="", telephone="", email="", password="")
      super(doRefs)
      self.update(login, firstName, lastName, institution, telephone, email, password)
    end

    # REUSE INSTANCE. Update this instance with new data; supports reuse of instances rather than always making new objects
    # [+login+] [optional; default=""] The login name of the user.
    # [+firstName+] [optional; default=""] User's "first" name.
    # [+lastName+] [optional; default=""] User's last name.
    # [+institution+] [optional; default=""] Institution the user is at, if any.
    # [+telephone+] [optional; default=""] User's phone number if any.
    # [+email+] [optional; default=""] User's email.
    def update(login, firstName, lastName, institution, telephone, email, password)
      @refs.clear() if(@refs)
      @login, @firstName, @lastName, @institution, @telephone, @email, @password =
        login, firstName, lastName, institution, telephone, email, password
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
                "login" => @login,
                "firstName" => @firstName,
                "lastName" => @lastName,
                "institution" => @institution,
                "telephone" => @telephone,
                "email" => @email,
                "password" => @password
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
        "login" => @login,
        "firstName" => @firstName,
        "lastName" => @lastName,
        "institution" => @institution,
        "telephone" => @telephone,
        "email" => @email,
        "password" => @password
      }
      data['refs'] = @refs if(@refs)
      retVal = (wrap ? self.wrap(data) : data)
      return retVal
    end
  end # class FullUserEntity < BRL::Genboree::REST::Data::AbstractEntity


  # FullUserEntityList - Object containing an array of FullUserEntity objects.
  # NOTE: the elements of this array are -FullUserEntity- objects. Inputs are
  # assumed to correctly be instances of FullUserEntity.
  #
  # Common Interface Methods:
  # - #to_json, #to_yaml, #to_xml        -- default implementations from parent class
  # - AbstractEntity.from_json, AbstractEntity.from_yaml, AbstractEntity.from_xml  -- default implementations from parent class
  # - #getFormatableDataStruct           -- default implementations from parent class
  class FullUserEntityList < EntityList
    # What formats are supported, using the conventional +Symbols+. Subclasses may or may not override this.
    FORMATS = [ :JSON, :XML, :YAML ]
    # A +Symbol+ naming the resource with a code-friendly (ok, XML tag-name friendly) name. This is currently used in
    # generating XML for _lists_...they will be lists of tags of this type (XML makes it hard to express certain natural things easily...)
    RESOURCE_TYPE = :UsrDetailedList

    # @return [String] The key for the reference url (when connect=yes)
    # @todo remove this and use JSON-LD @ref approach
    REFS_KEY = "#{RESOURCE_TYPE}_#{FORMATS.join('.')}"

    # What kind of objects does this collection/list store?
    ELEMENT_CLASS = FullUserEntity
    # Whether the values stored in @array are objects implementing toStructuredData() (constant to save reflection at runtime)
    ELEMENT_IMPLEMENTS_TOSTRUCTUREDDATA = ELEMENT_CLASS.method_defined?(:toStructuredData)
  end # class FullUserEntityList < BRL::Genboree::REST::Data::EntityList
  
  
  # DetailedUserEntity - Representation of a Genboree user: its login, name info, location/contact info, etc.
  # This level of info should really only be available to the user themselves. If accessing the info from
  # someone else, it's likely just the PartialUserEntity would be more appropriate.
  #
  # Common Interface Methods:
  # - #to_json, #to_yaml, #to_xml        -- default implementations from parent class
  # - AbstractEntity.from_json, AbstractEntity.from_yaml, AbstractEntity.from_xml  -- default implementations from parent class
  # - #getFormatableDataStruct           -- OVERRIDDEN
  class DetailedUserEntity < BRL::Genboree::REST::Data::AbstractEntity
    # What formats are supported, using the conventional +Symbols+. Subclasses may or may not override this.
    FORMATS = [ :JSON, :JSON_PRETTY, :XML, :YAML ]
    # A +Symbol+ naming the resource with a code-friendly (ok, XML tag-name friendly) name. This is currently used in
    # generating XML for _lists_...they will be lists of tags of this type (XML makes it hard to express certain natural things easily...)
    RESOURCE_TYPE = :UsrDetailed

    # @return [String] The key for the reference url (when connect=yes)
    # @todo remove this and use JSON-LD @ref approach
    REFS_KEY = "#{RESOURCE_TYPE}_#{FORMATS.join('.')}"

    # Any basic name-value type fields; i.e. where the value is not a complex data structure but rather some text or a number.
    # Framework will do some automatic processing and presentation of those for you. Subclasses will override this, obviously.
    SIMPLE_FIELD_NAMES = [ "login", "firstName", "lastName", "institution", "telephone", "email" ]

    # The login name of the user.
    attr_accessor :login
    # User's "first" name.
    attr_accessor :firstName
    # User's last name.
    attr_accessor :lastName
    # Institution the user is at, if any
    attr_accessor :institution
    # User's phone number if any
    attr_accessor :telephone
    # User's email.
    attr_accessor :email

    # CONSTRUCTOR.
    # [+doRefs+] [optional; default=true] Do you want the "refs" field in any representation of this entity (i.e. make connections or save size/complexity of representation?)
    # [+login+] [optional; default=""] The login name of the user.
    # [+firstName+] [optional; default=""] User's "first" name.
    # [+lastName+] [optional; default=""] User's last name.
    # [+institution+] [optional; default=""] Institution the user is at, if any.
    # [+telephone+] [optional; default=""] User's phone number if any.
    # [+email+] [optional; default=""] User's email.
    def initialize(doRefs=true, login="", firstName="", lastName="", institution="", telephone="", email="")
      super(doRefs)
      self.update(login, firstName, lastName, institution, telephone, email)
    end

    # REUSE INSTANCE. Update this instance with new data; supports reuse of instances rather than always making new objects
    # [+login+] [optional; default=""] The login name of the user.
    # [+firstName+] [optional; default=""] User's "first" name.
    # [+lastName+] [optional; default=""] User's last name.
    # [+institution+] [optional; default=""] Institution the user is at, if any.
    # [+telephone+] [optional; default=""] User's phone number if any.
    # [+email+] [optional; default=""] User's email.
    def update(login, firstName, lastName, institution, telephone, email)
      @refs.clear() if(@refs)
      @login, @firstName, @lastName, @institution, @telephone, @email =
        login, firstName, lastName, institution, telephone, email
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
                "login" => @login,
                "firstName" => @firstName,
                "lastName" => @lastName,
                "institution" => @institution,
                "telephone" => @telephone,
                "email" => @email
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
        "login" => @login,
        "firstName" => @firstName,
        "lastName" => @lastName,
        "institution" => @institution,
        "telephone" => @telephone,
        "email" => @email
      }
      data['refs'] = @refs if(@refs)
      retVal = (wrap ? self.wrap(data) : data)
      return retVal
    end
  end # class DetailedUserEntity < BRL::Genboree::REST::Data::AbstractEntity


  # DetailedUserEntityList - Object containing an array of DetailedUserEntity objects.
  # NOTE: the elements of this array are -DetailedUserEntity- objects. Inputs are
  # assumed to correctly be instances of DetailedUserEntity.
  #
  # Common Interface Methods:
  # - #to_json, #to_yaml, #to_xml        -- default implementations from parent class
  # - AbstractEntity.from_json, AbstractEntity.from_yaml, AbstractEntity.from_xml  -- default implementations from parent class
  # - #getFormatableDataStruct           -- default implementations from parent class
  class DetailedUserEntityList < EntityList
    # What formats are supported, using the conventional +Symbols+. Subclasses may or may not override this.
    FORMATS = [ :JSON, :JSON_PRETTY, :XML, :YAML ]
    # A +Symbol+ naming the resource with a code-friendly (ok, XML tag-name friendly) name. This is currently used in
    # generating XML for _lists_...they will be lists of tags of this type (XML makes it hard to express certain natural things easily...)
    RESOURCE_TYPE = :UsrDetailedList

    # @return [String] The key for the reference url (when connect=yes)
    # @todo remove this and use JSON-LD @ref approach
    REFS_KEY = "#{RESOURCE_TYPE}_#{FORMATS.join('.')}"

    # What kind of objects does this collection/list store?
    ELEMENT_CLASS = DetailedUserEntity
    # Whether the values stored in @array are objects implementing toStructuredData() (constant to save reflection at runtime)
    ELEMENT_IMPLEMENTS_TOSTRUCTUREDDATA = ELEMENT_CLASS.method_defined?(:toStructuredData)
  end # class DetailedUserEntityList < BRL::Genboree::REST::Data::EntityList


  # PartialUserEntity - Representation of a Genboree user, exposing _certain_ details suitable for sharing with other members of a user group:
  # its login, name info, institution, email; currently, telephone is not shared.
  #
  # Common Interface Methods:
  # - #to_json, #to_yaml, #to_xml        -- default implementations from parent class
  # - AbstractEntity.from_json, AbstractEntity.from_yaml, AbstractEntity.from_xml  -- default implementations from parent class
  # - #getFormatableDataStruct           -- OVERRIDDEN
  class PartialUserEntity < BRL::Genboree::REST::Data::DetailedUserEntity
    # Override key class constants used by inherited methods
    RESOURCE_TYPE = :UsrPartial

    # @return [String] The key for the reference url (when connect=yes)
    # @todo remove this and use JSON-LD @ref approach
    REFS_KEY = "#{RESOURCE_TYPE}_#{FORMATS.join('.')}"

    # A +Symbol+ naming the resource with a code-friendly (ok, XML tag-name friendly) name. This is currently used in
    # generating XML for _lists_...they will be lists of tags of this type (XML makes it hard to express certain natural things easily...)
    SIMPLE_FIELD_NAMES = [ "login", "firstName", "lastName", "institution", "email" ]

    # CONSTRUCTOR.
    # [+doRefs+] [optional; default=true] Do you want the "refs" field in any representation of this entity (i.e. make connections or save size/complexity of representation?)
    # [+login+] [optional; default=""] The login name of the user.
    # [+firstName+] [optional; default=""] User's "first" name.
    # [+lastName+] [optional; default=""] User's last name.
    # [+institution+] [optional; default=""] Institution the user is at, if any.
    # [+email+] [optional; default=""] User's email.
    def initialize(doRefs=true, login="", firstName="", lastName="", institution="", email="")
      super(doRefs)
      self.update(login, firstName, lastName, institution, nil, email)
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
                "login" => @login,
                "firstName" => @firstName,
                "lastName" => @lastName,
                "institution" => @institution,
                "email" => @email
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
        "login" => @login,
        "firstName" => @firstName,
        "lastName" => @lastName,
        "institution" => @institution,
        "email" => @email
      }
      data['refs'] = @refs if(@refs)
      retVal = (wrap ? self.wrap(data) : data)
      return retVal
    end
  end # class PartialUserEntity < BRL::Genboree::REST::Data::AbstractEntity

  # PartialUserEntityList - Object containing an array of PartialUserEntity objects.
  # NOTE: the elements of this array are PartialUserEntity objects. Inputs are
  # assumed to correctly be instances of PartialUserEntity.
  #
  # Common Interface Methods:
  # - #to_json, #to_yaml, #to_xml        -- default implementations from parent class
  # - AbstractEntity.from_json, AbstractEntity.from_yaml, AbstractEntity.from_xml  -- default implementations from parent class
  # - #getFormatableDataStruct           -- default implementations from parent class
  class PartialUserEntityList < BRL::Genboree::REST::Data::EntityList
    # Override key class constants used by inherited methods
    FORMATS = [ :JSON, :JSON_PRETTY, :XML, :YAML ]
    # A +Symbol+ naming the resource with a code-friendly (ok, XML tag-name friendly) name. This is currently used in
    # generating XML for _lists_...they will be lists of tags of this type (XML makes it hard to express certain natural things easily...)
    RESOURCE_TYPE = :UsrPartialList

    # @return [String] The key for the reference url (when connect=yes)
    # @todo remove this and use JSON-LD @ref approach
    REFS_KEY = "#{RESOURCE_TYPE}_#{FORMATS.join('.')}"

    # What kind of objects does this collection/list store?
    ELEMENT_CLASS = PartialUserEntity
    # Whether the values stored in @array are objects implementing toStructuredData() (constant to save reflection at runtime)
    ELEMENT_IMPLEMENTS_TOSTRUCTUREDDATA = ELEMENT_CLASS.method_defined?(:toStructuredData)
  end # class PartialUserEntityList < EntityList
end ; end ; end ; end  # module BRL ; module Genboree ; module REST ; module Data
