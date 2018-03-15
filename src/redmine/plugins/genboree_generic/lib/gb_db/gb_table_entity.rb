
module GbDb
  module GbTableEntity
    REQ_CLASS_METHOD_ALIASES = [ :byId, :byName ]

    # Add CLASS methods and automatical lookup/execution of EXPECTED CLASS methods
    def self.included(baseClass)
      baseClass.extend( AddClassAliases )
    end

    # Get the Redmine model-instance (entity) equivalent or nearest equivalent to this Genboree table entity instance.
    # @note This instance must reflect an existing Genboree record, else an Exception will be returned; not intended
    #   to be used to create arbitrary Redmine records that are not backed by a Genboree record. Some sanity checking
    #   is to be done on the Genboree object to make sure sufficient fields are filled etc.
    # @note Sub-classes should implement this where sensible. By default will raise a NotImplemented error, which
    #   may be appropriate when there is no clear 1:1 mapping between Genboree and Redmine (e.g. consider GbUserGroup)
    # @return [boolean] If your async callback has been accepted and will be called with a Hash argument with one of the two
    #   uniform keys, :obj or :err (see below)
    # @yieldparam [Hash<Symbol,Object>] results In NON-BLOCKING mode, your callback is called once the User instance is retrieved.
    #   Your code will be called with a single arg--a hash that has one of 2 keys:
    #   @option results [<<Redmine Model instance>>] :obj The instance of the Redmine model class.
    #   @option results [Exception] :err An exception or problem that occurred.
    # @raise [NotImplementedError] If the sub-class hasn't overridden and implemented this method.
    def redmineEntity( opts={}, &callback )
      raise NotImplementedError, "ERROR: #{self.class} has not implemented appropriate code to get the Redmine model-instance equivalent to this Genboree entity; or there IS NO sensible equivalent (in which case, what are you doing?)"
    end

    # Create the matching Redmine entity record matching this Genboree table record.
    # @note In addition to this instance being backed by an actual Genboree table record, several core/key fields MUST be
    #   sensible and filled it, else an error will be returned to your callback.
    # @note Additionally, certain internal Redmine fields may be populated automatically with appropriate
    #   values, and there is no facility for using your own possibly invalid values.
    # @note Sub-classes should implement this where sensible. By default will raise a NotImplemented error, which
    #   may be appropriate when there is no clear 1:1 mapping between Genboree and Redmine (e.g. consider GbUserGroup)
    # @return [boolean] If your async callback has been accepted and will be called with a Hash argument with one of the two
    #   uniform keys, :obj or :err (see below)
    # @yieldparam [Hash<Symbol,Object>] results In NON-BLOCKING mode, your callback is called once the User instance is retrieved.
    #   Your code will be called with a single arg--a hash that has one of 2 keys:
    #   @option results [<<Redmine Model instance>>] :obj The instance of the newly Redmine model class .
    #   @option results [Exception] :err An exception or problem that occurred.
    def createRedmineEntity( opts={}, &callback )
      raise NotImplementedError, "ERROR: #{self.class} has not implemented appropriate code to create the Redmine model-instance equivalent to this Genboree entity; or there IS NO sensible equivalent (in which case, what are you doing?)"
    end

    # Handle missing INSTANCE methods generically, as requests for column value [in most cases]
    #   with help of info from including class.
    # @return [Object, nil] The value for the field or nil if no such column or if value in table is NULL.
    def method_missing(methodSym, *args, &blk)
      column = methodSym.to_s.strip
      # Map column according to including class
      if( self.class::COLUMNS.key?( column ) )
        retVal = fieldValue( column )
      elsif( self.class::COLUMN_ALIASES.key?( column ) )
        column = self.class::COLUMN_ALIASES[column]
        retVal = fieldValue( column )
      else
        $stderr.debugPuts(__FILE__, __method__, 'NO SUCH COLUMN', "Cannot give value of the #{column.inspect} column; there is no such column.")
        retVal = nil
      end
      return retVal
    end

    # Get the value of some field in a loaded @gbUserGroupRec (i.e. must exist and have been loaded)
    # @param [String] field The field or column name to get the value for.
    # @return [Object, nil] The value of the field or nil if missing or there is no gbGroupRec.
    def fieldValue(field)
      return ( @rec.is_a?(Hash) ? @rec[field] : nil)
    end

    module AddClassAliases
      def method_missing(method, *args, &block)
        if( self.classMethodAliases[method].is_a?(Symbol) )
          self.send( self.classMethodAliases[method], *args, &block )
        elsif( REQ_CLASS_METHOD_ALIASES.include?(method) )
          raise NoMethodError, "ERROR: The #{self.inspect} class does not define directly nor declare an alias for required class method #{method.inspect}"
        else
          raise NoMethodError, "undefined method '#{method}' for #{self.inspect}"
        end
      end

      # Special factory instantiator. Can be used when instantiating by name makes no sense
      # @note The BLOCKING mode support is present here for backward compatibility only. It will not carry forward
      #   to new methods for this class.
      # @param [Hash] rackEnv The Rack env hash.
      # @return [GbDb::GbGroup] In BLOCKING mode, returns the instance. In NON-BLOCKING mode, your callback
      #   will be called with a Hash that contains the instance or error information (see below)
      # @yieldparam [Hash<Symbol,Object>] results In NON-BLOCKING mode, your callback is called once the instance is created
      #   and any available login info is retrieved. Your code will be called with a single arg--a hash that has one of just 1 key:
      #   @option results [Exception] :err An Exception telling you that trying to create this entity/record using a 'name' makes no sense
      def self.byNameInvalid( rackEnv, *args, &callback )
        rackCallback = rackEnv['async.callback'] rescue nil
        cb = ( block_given? ? SaferRackProc.withRackCallback( rackCallback, &Proc.new ) : SaferRackProc.withRackCallback( rackCallback, &callback ) )
        err = ArgumentError.new( "ERROR: there is no appropriate way to create a new row/record in the #{self.class::TABLE.inspect} table using a *name*. Doesn't make sense for the table.")
        cb.call( { :err => err } )
      end
    end
  end
end
