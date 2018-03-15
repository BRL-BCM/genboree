require 'mysql2'
require 'mysql2/em'
require 'brl/db/dbrc'

module GbDb

  # Encapsulates key access to the Genboree main MySQL database for the
  #  Genboree instance providing authentication services to this Redmine.
  #  Primarily the 'genboreegroup' table.
  #
  # @note The focus of this class is stuff *directly* related to a *specific* genboree group.
  #   Not even 'all groups' or sets of groups stuff. Don't pollute this with stuff that mainly
  #   concerned with other tables or concerns. Make a new class.
  class GbGroup < GbDb::DbConnection
    include GbTableEntity

    TABLE = 'genboreegroup'
    COLUMNS = {
      'groupId'     => false,
      'groupName'   => false,
      'description' => true,
      'student'     => true
    }
    COLUMN_ALIASES = {
      'recId' => 'groupId',
      'name'  => 'groupName'
    }
    # The names of this entity can differ by case alone.
    CASE_SENSITIVE_NAME = false

    METHOD_INFO = {
      :initialize => {
        :opts => { :name => nil, :groupId => nil, :dbHost => nil, :caseSensitive => self::CASE_SENSITIVE_NAME, :emCompliant => true }
      },
      :byGroupName => {
        :opts => { :caseSensitive => self::CASE_SENSITIVE_NAME, :emCompliant => true }
      },
      :byGroupId => {
        :opts => { :caseSensitive => self::CASE_SENSITIVE_NAME, :emCompliant => true }
      },
      :create => {
        :opts => { :caseSensitive => self::CASE_SENSITIVE_NAME, :emCompliant => true }
      }
    }

    # Use metaclass to let GbTableEntity method get info and call CLASS "instance" methods
    class << self
      attr_accessor :classMethodAliases
      # GbTableEntity expects this class to have some methods that can be used for generic
      #   byId or byName, if we haven't named them that already. If not, map them here.
      GbGroup.classMethodAliases = {
        :byId   => :byGroupId,
        :byName => :byGroupName
      }
    end

    # No calling new(). Use a factory method to get instance.
    private_class_method :new

    attr_reader :gbAuthHelper, :authHost
    attr_reader :warnings

    # Factory instantiator. Instantiate for known genboree group.
    # @note The BLOCKING mode support is present here for backward compatibility only. It will not carry forward
    #   to new methods for this class.
    # @note Group names are case-sensitive.
    # @param [Hash] rackEnv The Rack env hash.
    # @param [String] name The genboree group name.
    # @param [Hash{Symbol,Object}] opts Additional opts affecting the account or this object. If the MySQL instance host
    #   is known, it can be provided via the :dbHost key. Otherwise it will be looked up.
    #   @option opts [boolean] :caseSensitive Default true. Login is case-sensitive in most situations. Obvious
    #     exception is when creating a new user and first checking if already exists (should check case-insensitve)
    #     to avoid confusing logins that differ only by case...probably user re-registration error. So can use this to override.
    # @return [GbDb::GbGroup] In BLOCKING mode, returns the instance. In NON-BLOCKING mode, your callback
    #   will be called with a Hash that contains the instance or error information (see below)
    # @yieldparam [Hash<Symbol,Object>] results In NON-BLOCKING mode, your callback is called once the instance is created
    #   and any available login info is retrieved. Your code will be called with a single arg--a hash that has one of 2 keys:
    #   @option results [Array<Hash>] :obj The instance of this class.
    #   @option results [Exception] :err An exception that occurred.
    def self.byGroupName( rackEnv, name, opts={}, &callback )
      # Options
      methodInfo = METHOD_INFO[__method__]
      opts = methodInfo[:opts].merge(opts)

      rackCallback = rackEnv['async.callback'] rescue nil
      caseSense = ( ( opts and !opts[:caseSensitive].nil? ) ? opts[:caseSensitive] : self::CASE_SENSITIVE_NAME )
      cb = ( block_given? ? SaferRackProc.withRackCallback( rackCallback, &Proc.new ) : SaferRackProc.withRackCallback( rackCallback, &callback ) )
      newErr = nil
      # No-go decisions
      if( !name.blank? )
        # Instantiate empty
        begin
          obj = new( rackEnv, opts.merge( { :name => name, :groupId => nil, :caseSensitive => caseSense } ) )
        rescue Exception => newErr
          obj = nil
        end
        # Use reload() to load details, if available
        if(cb) # NON-BLOCKING
          if( obj )
            obj.reload() { |results|
              if(results[:rows])
                cb.call( { :obj => obj } )
              else
                cb.call( { :err => results[:err] } )
              end
            }
            retVal = true
          else # Exception raised during new()
            cb.call( { :err => newErr } )
            retVal = false
          end
        else # BLOCKING
          if( obj )
            obj.reload()
            retVal = obj
          else # Exception raised during new()
            raise newErr
          end
        end
      else
        msg = "ERROR: group name argument cannot be blank"
        if( cb ) # NON-BLOCKING
          customErrorViaCallback( rackCallback, ArgumentError, msg, &cb )
          retVal = false
        else # BLOCKING
          raise ArgumentErr, msg
        end
      end

      return retVal
    end

    # Factory instantiator. Instantiate for known genboree groupId (row id).
    # @param [Hash] rackEnv The Rack env hash.
    # @param [Fixnum] groupId The genboree group groupId number.
    # @param [Hash{Symbol,Object}] opts Additional opts affecting the account or this object. If the MySQL instance host
    #   is known, it can be provided via the :dbHost key. Otherwise it will be looked up.
    # @return [GbDb::GbGroup] Instance.
    # @yieldparam [Hash<Symbol,Object>] results Your callback is called once the instance is created.
    #   Your code will be called with a single arg--a hash that has one of 2 keys:
    #   @option results [Array<Hash>] :obj The instance of this class.
    #   @option results [Exception] :err An exception that occurred.
    def self.byGroupId( rackEnv, groupId, opts=self::METHOD_INFO[__method__][:opts], &callback )
      # Options
      methodInfo = METHOD_INFO[__method__]
      opts = methodInfo[:opts].merge(opts)

      rackCallback = rackEnv['async.callback'] rescue nil
      cb = ( block_given? ? SaferRackProc.withRackCallback( rackCallback, &Proc.new ) : SaferRackProc.withRackCallback( rackCallback, &callback ) )
      newErr = nil
      # No-go decisions
      if( !name.blank? )
        # Instantiate empty
        begin
          obj = new( rackEnv, opts.merge( { :groupId => groupId, :name => nil } ) )
        rescue Exception => newErr
          obj = nil
        end

        if( cb )
          if( obj )
            # Use reload() to load details, if available
            obj.reload() { |results|
              if(results[:rows])
                cb.call( { :obj => obj } )
              else
                cb.call( { :err => results[:err] } )
              end
            }
            retVal = true
          else # Exception raised during new()
            cb.call( { :err => newErr } )
            retVal = false
          end
        else
          customErrorViaCallback( rackCallback, ArgumentError, "ERROR: you must supply a callback method by providing a code block (anonymous block or via &arg)", &cb )
          retVal = false
        end
      else
        customErrorViaCallback( rackCallback, ArgumentError, "ERROR: groupId argument cannot be blank", &cb )
        retVal = false
      end

      return retVal
    end

    # "Create" - Create a new genboree group. Given a group name, plus values for the other record fields,
    #   try to create a new group with that name and other field values. If already exists, an error will be communicated
    #   to your callback.
    # Thus you can use this to generate NEW GENBOREE GROUP.
    # @note NON-BLOCKING. You need to privde a callback.
    # @param [Hash] rackEnv The Rack env hash.
    # @param [String] name The genboree group name you wish to create or update.
    # @param [String] description Optional. Default ''. The group description.
    # @param [String] student Optional. Default 2. Legacy column; should not be needed nor used by recent Genboree services.
    # @yieldparam [Hash<Symbol,Object>] results Your callback is called once the results are ready.
    #   Your code will be called with a single arg--a hash that has one of 2 keys:
    #   @option results [Array<Hash>] :count The rows-changed count.
    #   @option results [Exception] :err An exception that occurred.
    def self.create(rackEnv, name, description='', student=2, opts={}, &callback)
      # Options
      methodInfo = METHOD_INFO[__method__]
      opts = methodInfo[:opts].merge(opts)

      rackCallback = rackEnv['async.callback'] rescue nil
      cb = ( block_given? ? SaferRackProc.withRackCallback( rackCallback, &Proc.new ) : SaferRackProc.withRackCallback( rackCallback, &callback ) )
      # No-go decisions
      if( cb )
        # Try to create new instance AND populate it from database (should not be able to populate)
        opts[:caseSensitive] = self::CASE_SENSITIVE_NAME
        self.byName(rackEnv, name, opts) { |results|
          obj = results[:obj] rescue nil
          if( obj ) # then no sql error querying database etc, yay
            if( obj.groupId.nil? ) # and no existing record for login, yay
              # Create via upsert...which due to the byName() will be an insert if it's done.
              obj.upsert(name, description, student ) { |upsertResults|
                count = upsertResults[:count]
                if(count and count > 0) # Then went as expected
                  cb.call( { :obj => obj } )
                else # Error? bad count?
                  if(count)
                    customErrorViaCallback( rackCallback, RuntimeError, "Insert of new record returned suspect rows-affected count of #{count.inspect}", &cb )
                  else # better be an :err
                    cb.call( upsertResults )
                  end
                end
              }
            else # not empty, already is a group record with that name
              customErrorViaCallback( rackCallback, IndexError, "There is already a genboree group record with the name #{name.inspect}, cannot use this #{__method__.inspect} to create another.", &cb )
            end
          else # Some error just querying for existing record via name!
            cb.call( results )
          end
        }
        retVal = true
      else
        customErrorViaCallback( rackCallback, ArgumentError, "ERROR: you must supply a callback method by providing a code block (anonymous block or via &arg)", &cb )
        retVal = false
      end

      return retVal
    end

    # Get the genboreegroup row/record for the group as a Hash. If already retrieved, uses in-memory version.
    # @note ONLY works as non-blocking. Older BLOCKING approach not supported by this method.
    # @yieldparam [Hash<Symbol,Object>] results Your callback is called once the results are ready.
    #   Your code will be called with a single arg--a hash that has one of 2 keys:
    #   @option results [Array<Hash>] :rows The output rows.
    #   @option results [Exception] :err An exception that occurred or was noticed.
    def gbGroupRec(&callback)
      cb = ( block_given? ? saferRackProc( &Proc.new ) : saferRackProc( &callback ) )
      # No-go decisions
      if( cb )
        if(@gbGroupRec)
          # Then we have already available, immediately call callback with it
          cb.call( { :rows => [ @gbGroupRec ] } )
        else
          # Need to get it.
          if( !@objFor[:name].blank? )
            groupRecByGbName(@objFor[:name], { :caseSensitive => @objFor[:caseSensitive] }, &cb )
          else # assume groupId
            groupRecByGbGroupId(@objFor[:groupId], &cb )
          end
        end
        retVal = true
      else
        customErrorViaCallback( ArgumentError, "ERROR: you must supply a callback method by providing a code block (anonymous block or via &arg)", &cb )
        retVal = false
      end

      return retVal
    end
    alias_method :tableRec, :gbGroupRec

    # Change description for existing genboree group.
    # @note NON-BLOCKING. You need to provide a callback.
    # @param [String] name The genboree group name for which you have a new description.
    # @param [String] description The new description.
    # @yieldparam [Hash<Symbol,Object>] results Your callback is called once the results are ready.
    #   Your code will be called with a single arg--a hash that has one of 2 keys:
    #   @option results [Array<Hash>] :count The rows-changed count. Should be 1, else OH NO.
    #   @option results [Exception] :err An exception that occurred.
    def descriptionUpdate(name, description, &callback)
      cb = (block_given? ? Proc.new : callback) # will use saferRackProc() in fieldUpdate()
      return fieldUpdate(name, 'description', description, &cb )
    end

    # Change student for existing genboree group.
    # @note You should NOT BE MESSING WITH THIS. Deprecated / legacy only.
    # @note NON-BLOCKING. You need to provide a callback.
    # @param [String] name The genboree group name for which you have a new student.
    # @param [String] student The new student.
    # @yieldparam [Hash<Symbol,Object>] results Your callback is called once the results are ready.
    #   Your code will be called with a single arg--a hash that has one of 2 keys:
    #   @option results [Array<Hash>] :count The rows-changed count. Should be 1, else OH NO.
    #   @option results [Exception] :err An exception that occurred.
    def studentUpdate(name, student, &callback)
      cb = (block_given? ? Proc.new : callback) # will use saferRackProc() in fieldUpdate()
      $stderr.debugPuts(__FILE__, __method__, 'WARNING', "Why are you messing with the legacy 'student' column of the genboree group #{name.inspect}??")
      return fieldUpdate(name, 'student', student, &cb )
    end
    
    # Change a specific field for genboree group.
    # @note NON-BLOCKING. You need to provide a callback.
    # @note Group name is used case-sensitively to select group row to update
    # @param [String] name The genboree group name which you want to update some field's value.
    # @param [String] field The field in the genboreegroup record to change. Cannot be 'name' nor 'groupName' nor 'groupId'.
    # @param [String] value The new value for field. Note that no value can be nil. Many fields like the name also cannot be blank and
    #   some others may have additional constraints
    # @yieldparam [Hash<Symbol,Object>] results Your callback is called once the results are ready.
    #   Your code will be called with a single arg--a hash that has one of 2 keys:
    #   @option results [Array<Hash>] :count The rows-changed count.
    #   @option results [Exception] :err An exception that occurred. Will be an ArgumentError if the field is unknown,
    #   or if field is unchangeable.
    def fieldUpdate(name, field, value, &callback)
      retVal = true
      field = field.to_s.strip
      field = 'groupName' if( field == 'name' )
      value = value.to_s.strip
      cb = ( block_given? ? saferRackProc( &Proc.new ) : saferRackProc( &callback ) )
      argErrMsg = false
      # No-go decisions
      if( cb )
        if( !COLUMNS.key?(field) )
          argErrMsg = "ERROR: No such column #{field.inspect} in genboreegroup table."
        elsif( !COLUMNS[field] )
          argErrMsg = "ERROR: Cannot change #{field.inspect} for existing group records."
        end

        if( !argErrMsg )
          updateColumnsByFieldAndValue( TABLE, { field => value }, { 'groupName' => name }, :and, { :smartBinMode => self.class::CASE_SENSITIVE_NAME } ) { |results|
            if( results[:count] )
              # If things went ok, need to do a reload() to refresh data in this object
              reload() { |reloadResults|
                #$stderr.debugPuts(__FILE__, __method__, 'DEBUG', "reloadResults:\n\n#{reloadResults.inspect}\n\n")
                if( reloadResults[:err] )
                  err = reloadResults[:err]
                  msg = "Update appears to have succeeded, but trying to reload the record to refresh this object seems to have failed."
                  $stderr.debugPuts(__FILE__, __method__, 'WARNING', "#{msg}.\n    Error class: #{err.class rescue nil}\n    Error Msg: #{err.message rescue nil}\n    Error Trace:\n#{err.backtrace.join("\n") rescue nil}")
                end
                # Regardless, we call dev's callback with update's results
                cb.call( results )
              }
            else # update didn't go ok so no reload
              cb.call( results )
            end
          }
          retVal = true
        else
          customErrorViaCallback( ArgumentError, argErrMsg, &cb )
          retVal = false
        end
      else
        customErrorViaCallback( ArgumentError, "ERROR: you must supply a callback method by providing a code block (anonymous block or via &arg)", &cb )
        retVal = false
      end
      return retVal
    end

    # "Upsert" - update existing record / insert new record. Given a group, plus values for the other record fields,
    #   either insert a new record for that group if it doesn't exist (remember groupId is autoincrement and thus not
    #   provided here) OR if the group already exists then update all its column values to be those provided.
    # Thus you can use this to generate NEW GENBOREE GROUP, OR to update 'description' for an EXISTING GENBOREE USER.
    # @note Using this to update just 1 field like 'description' is not very smart. There are some dedicated update
    #   methods for some common fields as well as the flexible {#fieldUpdate} method that can update any of the valid fields.
    # @note NON-BLOCKING. You need to privde a callback.
    # @param [String] name The genboree group name you wish to create or update.
    # @param [String] description Optional. Default ''. The group description.
    # @param [String] student Optional. Default 2. Legacy column; should not be needed nor used by recent Genboree services.
    # @yieldparam [Hash<Symbol,Object>] results Your callback is called once the results are ready.
    #   Your code will be called with a single arg--a hash that has one of 2 keys:
    #   @option results [Array<Hash>] :count The rows-changed count.
    #   @option results [Exception] :err An exception that occurred.
    def upsert(name, description='', student=2, &callback)
      retVal = true
      description = description.to_s.strip
      student = student.to_s.strip
      cb = ( block_given? ? saferRackProc( &Proc.new ) : saferRackProc( &callback ) )

      # No-go decisions
      if( cb )
        identCols = [ 'groupName' ]
        col2val = {
          'groupName'   => name,
          'description' => description,
          'student'     => student
        }
        #$stderr.debugPuts(__FILE__, __method__, 'DEBUG', "col2val:\n\n#{JSON.pretty_generate(col2val)}\n\n")
        upsertByFieldValueMap( TABLE, col2val, identCols ) { |results|
          if( results[:count] )
            # If things went ok, need to do a reload() to refresh data in this object
            reload() { |reloadResults|
              if( reloadResults[:err] )
                err = reloadResults[:err]
                msg = "Upsert appears to have succeeded, but trying to reload the record to refresh this object seems to have failed."
                $stderr.debugPuts(__FILE__, __method__, 'WARNING', "#{msg}.\n    Error class: #{err.class rescue nil}\n    Error Msg: #{err.message rescue nil}\n    Error Trace:\n#{err.backtrace.join("\n") rescue nil}")
              end
              # Regardless, we call dev's callback with update's results
              cb.call( results )
            }
          else # update didn't go ok so no reload
            cb.call( results )
          end
        }
        retVal = true
      else
        customErrorViaCallback( ArgumentError, "ERROR: you must supply a callback method by providing a code block (anonymous block or via &arg)", &cb )
        retVal = false
      end

      return retVal
    end

    # Get the genboreegroup table record for groupId.
    # @note You should NOT be calling this directly. Use one of the methods above.
    # @note Only intended to be used in non-blocking mode.
    # @param [String] groupId The groupId of the group of interest.
    # @return [Array, nil] Should be @true@ and your callback block/Proc will be called with a results Hash (see below).
    # @yieldparam [Hash<Symbol,Object>] results In async / non-blocking mode, your callback is called once the results are ready.
    #   Your code will be called with a single arg--a hash that has one of 2 keys:
    #   @option results [Array<Array>] :rows The output rows.
    #   @option results [Exception] :err An exception that occurred.
    def groupRecByGbGroupId( groupId, opts={}, &callback )
      retVal = true
      cb = ( block_given? ? saferRackProc( &Proc.new ) : saferRackProc( &callback ) )

      # No-go decisions
      if( cb )
        selectByFieldWithMultipleValues(TABLE, 'groupId', [groupId]) { |results|
          # Save the retrieved record, if any, and use it to update key object state
          setStateFromResults( results )
          cb.call( results )
        }
        retVal = true
      else
        customErrorViaCallback( ArgumentError, "ERROR: you must supply a callback method by providing a code block (anonymous block or via &arg)", &cb )
        retVal = false
      end
      return retVal
    end

    # Get the genboreegroup table record for group.
    # @note Only intended to be used in non-blocking mode.
    # @note Group names are case-sensitive
    # @param [String] groupId The name of the group of interest.
    # @return [Array, nil] Should be @true@ and your callback block/Proc will be called with a results Hash (see below).
    # @yieldparam [Hash<Symbol,Object>] results In async / non-blocking mode, your callback is called once the results are ready.
    #   Your code will be called with a single arg--a hash that has one of 2 keys:
    #   @option results [Array<Array>] :rows The output rows.
    #   @option results [Exception] :err An exception that occurred.
    def groupRecByGbName(name, opts={ :caseSensitive => self.class::CASE_SENSITIVE_NAME }, &callback )
      retVal = true
      caseSense = opts[:caseSensitive]
      cb = ( block_given? ? saferRackProc( &Proc.new ) : saferRackProc( &callback ) )

      # No-go decisions
      if( cb )
        selectByFieldWithMultipleValues(TABLE, 'groupName', [name], { :smartBinMode => caseSense } ) { |results|
          # Save the retrieved record, if any, and use it to update key object state
          setStateFromResults(results )
          cb.call( results )
        }
        retVal = true
      else
        customErrorViaCallback( ArgumentError, "ERROR: you must supply a callback method by providing a code block (anonymous block or via &arg)", &cb )
        retVal = false
      end

      return retVal
    end

    # ----------------------------------------------------------------
    # HELPERS - meant for internal use but not private in case there is utility for
    #   tightly-coupled classes.
    # ----------------------------------------------------------------

    # Try to reload the @gbGroupRec using the info provided when object was initialized.
    # @return [true] In both blocking and non-blocking mode, this method returns true if the reload attempt completes.
    #   You can interrogate this object--in limited ways if blocking--for data, if any was found.
    # @yieldparam [Hash<Symbol,Object>] results Your callback is called once the results are ready.
    #   Your code will be called with a single arg--a hash that has one of 2 keys:
    #   @option results [Array<Hash>] :rows The output rows.
    #   @option results [Exception] :err An exception that occurred.
    def reload(&callback)
      cb = ( block_given? ? saferRackProc( &Proc.new ) : saferRackProc( &callback ) )
      @gbGroupRec = nil
      if(cb) # Then NON-BLOCKING mode
        # Use gbGroupRec(), which is non-blocking mode only and does right thing.
        gbGroupRec(&callback)
        retVal = true
      else # BLOCKING mode
        # Similar code as in gbGroupRec() but blocking versions.
        if( !@objFor[:name].blank? )
          caseSense = ( ( @objFor.is_a?(Hash) and !@objFor[:caseSensitive].nil? ) ? @objFor[:caseSensitive] : self.class::CASE_SENSITIVE_NAME )
          groupRecByGbName( @objFor[:name], { :caseSensitive => caseSense }  )
        else # assume groupId
          raise ArgumentError, "ERROR: you cannot instantiate using groupId without providing a callback."
        end
        retVal = true
      end
      return retVal
    end

    private

    # Private constructor. Instantiate via EITHER name or groupId.
    # @note Meant to be called by the public factory constructor methods.
    # @param [Hash] rackEnv The Rack env hash.
    # @param [Hash{Symbol,Object}] opts A Hash with one and only one of 2 keys providing the info to be used to instantiate
    #   the object, and optionally a :dbHost key if you know the MySQL instance host to connect to (else GbApi::GbAuthHelper
    #   will be created and asked for the appropriate host info).
    #   @options opts [String] :name The genboree group name ('groupName' column value)
    #   @options opts [Fixnum] :groupId The genboree group id (row id)
    #   @options opts [String] :dbHost The MySQL instance host to connect to, if known. If not {GbApi::GbAuthHelper}
    #     will be instantiated to answer this.
    # @raise ArgumentError If you provide values for more than one of, or none of, :name :groupId
    def initialize( rackEnv, opts={ :dbHost => host } )
      # Options
      methodInfo = METHOD_INFO[__method__]
      opts = methodInfo[:opts].merge(opts)

      @objFor = { :name => opts[:name], :groupId => opts[:groupId], :caseSensitive => opts[:caseSensitive] }
      unless( [:name, :groupId].one?{|kk| !@objFor[kk].to_s.blank?} )
        raise ArgumentError, "ERROR: Must provide one (and only one) of :name or :groupId keys; whichever is provided will be used to find the group record (if any exists). Maybe you should use the simpler factory methods GbGroup.byName() or GbGroup.byId(). @objFor was: #{@objFor.inspect}"
      end
      if( !opts[:dbHost].to_s.blank? )
        @authHost = opts[:dbHost]
      else
        @gbAuthHelper = GbApi::GbAuthHelper.new( rackEnv )
        @authHost = @gbAuthHelper.gbAuthHost()
      end
      # Do parent class initialize

      super(rackEnv, @authHost, opts)
    end

    # Get the value of some field in a loaded @gbGroupRec (i.e. must exist and have been loaded)
    # @param [String] field The field or column name to get the value for.
    # @return [Object, nil] The value of the field or nil if missing or there is no gbGroupRec.
    def fieldValue(field)
      return ( @gbGroupRec.is_a?(Hash) ? @gbGroupRec[field] : nil)
    end

    # Update the state of this object from a result set--generally from a lookup query. If results empty or
    #   or invalid (no record found or perhaps error) then update state appropriately.
    # @note Upon updating from actual row/record, the @@objFor@ instance variable will change to contain the *groupId*
    #   for the record. Thus @@objFor@ content may be different than right after initialization, where it contained
    #   group name [possibly non-existent] info provided. Having this updated correctly is a key reason for this method.
    # @param [Hash{Symbol,Object}, Array<Hash>] results In EM-compliant non-blocking mode, result sets are wrapped
    #   in a uniform Hash so that the :rows (or :count or :obj) can be provided OR an :err exception can be communicated.
    #   But in older BLOCKING mode, result sets are the table of rows (Hashes) directly, with no wrapper. This method handles
    #   both cases.
    # @return [Hash, nil] The user record this object is representing, or nil if no such record available [yet].
    def setStateFromResults( results )
      retVal = nil
      # Handle both EM-compliant wrapped result set and older blocking direct result set.
      if( ( results.is_a?(Hash) and results[:rows].is_a?(Array) ) or ( results.is_a?(Array) ) )
        rec = ( results.is_a?(Hash) ? results[:rows].first : results.first )
        if( rec )
          @gbGroupRec = rec
          # Switch from however initialized to groupId based reloading (in case of update or other changes)
          caseSense = ( (@objFor.is_a?(Hash) and !@objFor[:caseSensitive].nil?) ? @objFor[:caseSensitive] : true )
          @objFor = { :groupId => fieldValue('groupId'), :name => nil, :caseSensitive => caseSense }
        else # no rec found
          # Leave objFor unchanged, since no better info available
          @gbGroupRec = nil
        end
        retVal = @gbGroupRec
      end
      return retVal
    end
  end
end
