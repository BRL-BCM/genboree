require 'mysql2'
require 'mysql2/em'
require 'brl/db/dbrc'

module GbDb

  # Encapsulates key access to the Genboree main MySQL database for the
  #  Genboree instance providing authentication services to this Redmine.
  #  Primarily the 'usergroup' table.
  class GbUserGroup < GbDb::DbConnection
    include GbTableEntity

    TABLE = 'usergroup'
    COLUMNS = {
      'userGroupId'     => false,
      'groupId'         => false,
      'userId'          => false,
      'userGroupAccess' => true,
      'permissionBits'  => true
    }
    COLUMN_ALIASES = {
      'recId' => 'userGroupId',
      'role'  => 'userGroupAccess'
    }
    ROLES2MODES = {
      :administrator  => 'o',
      :author         => 'w',
      :subscriber     => 'r'
    }
    MODES2ROLES = self::ROLES2MODES.reduce({}) { |acc, pair| acc[pair[1]] = pair[0] ; acc }

    METHOD_INFO = {
      :initialize => {
        :opts => { :userGroupId => nil, :groupId => nil, :userId => nil, :dbHost => nil, :emCompliant => true }
      },
      :byUserGroupId => {
        :opts => { :emCompliant => true }
      },
      :byGroupAndUserIds => {
        :opts => { :emCompliant => true }
      },
      :create => {
        :opts => { :emCompliant => true }
      }
    }

    # Use metaclass to let GbTableEntity method get info and call CLASS "instance" methods
    class << self
      attr_accessor :classMethodAliases
      # GbTableEntity expects this class to have some methods that can be used for generic
      #   byId or byName, if we haven't named them that already. If not, map them here.
      GbUserGroup.classMethodAliases = {
        :byId   => :byUserGroupId,
        :byName => :ByNameInvalid
      }
    end

    # No calling new(). Use a factory method to get instance.
    private_class_method :new

    attr_reader :gbAuthHelper, :authHost
    attr_reader :warnings
    
    # Factory instantiator. Instantiate for known genboree userGroupId (row id).
    # @param [Hash] rackEnv The Rack env hash.
    # @param [Fixnum] userGroupId The genboree usergroup userGroupId number.
    # @param [Hash{Symbol,Object}] opts Additional opts affecting the account or this object. If the MySQL instance host
    #   is known, it can be provided via the :dbHost key. Otherwise it will be looked up.
    # @return [GbDb::GbUserGroup] Instance.
    # @yieldparam [Hash<Symbol,Object>] results Your callback is called once the instance is created.
    #   Your code will be called with a single arg--a hash that has one of 2 keys:
    #   @option results [Array<Hash>] :obj The instance of this class.
    #   @option results [Exception] :err An exception that occurred.
    def self.byUserGroupId( rackEnv, userGroupId, opts={}, &callback )
      # Options
      methodInfo = METHOD_INFO[__method__]
      opts = methodInfo[:opts].merge(opts)

      rackCallback = rackEnv['async.callback'] rescue nil
      cb = ( block_given? ? SaferRackProc.withRackCallback( rackCallback, &Proc.new ) : SaferRackProc.withRackCallback( rackCallback, &callback ) )
      newErr = nil
      # No-go decisions
      if( !userGroupId.blank? )
        # Instantiate empty
        begin
          obj = new( rackEnv, opts.merge( { :userGroupId => userGroupId } ) )
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

    # Factory instantiator. Instantiate for known genboree group.
    # @param [Hash] rackEnv The Rack env hash.
    # @param [String, Fixnum] groupId The genboree group id for which you want to get user's membership info
    # @param [String, Fixnum] userId The genboree user id for which you want to get the group membership info
    # @param [Hash{Symbol,Object}] opts Additional opts affecting the account or this object. If the MySQL instance host
    #   is known, it can be provided via the :dbHost key. Otherwise it will be looked up.
    # @return [GbDb::GbUserGroup] In BLOCKING mode, returns the instance. In NON-BLOCKING mode, your callback
    #   will be called with a Hash that contains the instance or error information (see below)
    # @yieldparam [Hash<Symbol,Object>] results In NON-BLOCKING mode, your callback is called once the instance is created
    #   and any available login info is retrieved. Your code will be called with a single arg--a hash that has one of 2 keys:
    #   @option results [Array<Hash>] :obj The instance of this class.
    #   @option results [Exception] :err An exception that occurred.
    def self.byGroupAndUserIds( rackEnv, groupId, userId, opts={}, &callback )
      # Options
      methodInfo = METHOD_INFO[__method__]
      opts = methodInfo[:opts].merge(opts)

      rackCallback = rackEnv['async.callback'] rescue nil
      cb = ( block_given? ? SaferRackProc.withRackCallback( rackCallback, &Proc.new ) : SaferRackProc.withRackCallback( rackCallback, &callback ) )
      newErr = nil
      # No-go decisions
      if( !groupId.blank? and !userId.blank? )
        # Instantiate empty
        begin
          obj = new( rackEnv, opts.merge( { :userGroupId => nil, :groupId => groupId, :userId => userId } ) )
        rescue Exception => newErr
          obj = nil
        end

        if( cb )
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
        else
          customErrorViaCallback( rackEnv, ArgumentError, "ERROR: you must supply a callback method by providing a code block (anonymous block or via &arg)", &cb )
          retVal = false
        end
      else
        customErrorViaCallback( rackEnv, ArgumentError, "ERROR: must provide non blank and specific groupId AND userId", &cb )
        retVal = false
      end

      return retVal
    end
    
    # "Create" - Create a new usergroup record (user-group membership). Given a groupId and a userId and a role code,
    #   try to create a new usergroup record. If already exists, an error will be communicated
    #   to your callback.
    # @note NON-BLOCKING. You need to privde a callback.
    # @param [Hash] rackEnv The Rack env hash.
    # @param [String, Fixnum] groupId The genboree group id for which you want to create user's membership info
    # @param [String, Fixnum] userId The genboree user id for which you want to create the group membership info
    # @param [String, Symbol] role Either the single letter role code or a Symbol correspoinding to a role.
    #   'r'  or :subscriber for read-only subscriber ; 'w' or :author for write-capable author ; or 'o' or :administrator
    #   for a owner-like administratior. Stored in the 'userGroupAccess' column.
    # @param [Fixnum] permissionBits Optional. Default 0. Set the permission bits number if you know about special cases (infrequent).
     # @yieldparam [Hash<Symbol,Object>] results Your callback is called once the results are ready.
    #   Your code will be called with a single arg--a hash that has one of 2 keys:
    #   @option results [Array<Hash>] :count The rows-changed count.
    #   @option results [Exception] :err An exception that occurred. Will be an ArgumentError  if the field is unknown,
    #     or if field is unchangeable, or if password and value is black or too short, or if email doesn't look even a little
    #     bit like an email address, or if the first/last name values are blank, etc.
    def self.create(rackEnv, groupId, userId, role, permissionBits=0, opts={}, &callback)
      # Options
      methodInfo = METHOD_INFO[__method__]
      opts = methodInfo[:opts].merge(opts)

      rackCallback = rackEnv['async.callback'] rescue nil
      cb = ( block_given? ? SaferRackProc.withRackCallback( rackCallback, &Proc.new ) : SaferRackProc.withRackCallback( rackCallback, &callback ) )
      # No-go decisions
      if( cb )
        # Try to create new instance AND populate it from database (should not be able to populate)
        self.byGroupAndUserIds(rackEnv, groupId, userId, opts) { |results|
          obj = ( results[:obj] or results[:err] )
          if( obj ) # then no sql error querying database etc, yay
            if( obj.userGroupId.nil? ) # and no existing record for login, yay
              # Create via upsert...which due to the byGroupAndUserIds() will be an insert if it's done.
              obj.upsert( groupId, userId, role, permissionBits ) { |upsertResults|
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
              customErrorViaCallback( rackCallback, IndexError, "There is already a membership record in usergroup for the userId #{userId.inspect} in the group with groupId #{groupId.inspect} cannot create() to update specific membership info.", &cb )
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

    def roleForUser()
      userAccessMode = self.role
      return self.class::MODES2ROLES[userAccessMode]
    end

    def accessModeForUser()
      self.userGroupAccess
    end

    # Get the usergroup row/record for the group as a Hash. If already retrieved, uses in-memory version.
    # @note ONLY works as non-blocking. Older BLOCKING approach not supported by this method.
    # @yieldparam [Hash<Symbol,Object>] results Your callback is called once the results are ready.
    #   Your code will be called with a single arg--a hash that has one of 2 keys:
    #   @option results [Array<Hash>] :rows The output rows.
    #   @option results [Exception] :err An exception that occurred or was noticed.
    def gbUserGroupRec(&callback)
      cb = ( block_given? ? saferRackProc( &Proc.new ) : saferRackProc( &callback ) )
      # No-go decisions
      if( cb )
        if(@rec)
          # Then we have already available, immediately call callback with it
          cb.call( { :rows => [ @rec ] } )
        else
          # Need to get it.
          if( !@objFor[:userGroupId].to_s.blank? )
            userGroupRecById(@objFor[:userGroupId], &cb )
          else # assume groupId
            userGroupRecByGroupAndUserId(@objFor[:groupId], @objFor[:userId], &cb )
          end
        end
        retVal = true
      else
        customErrorViaCallback( ArgumentError, "ERROR: you must supply a callback method by providing a code block (anonymous block or via &arg)", &cb )
        retVal = false
      end

      return retVal
    end
    alias_method :tableRec, :gbUserGroupRec

    # Change role for existing genboree group.
    # @note NON-BLOCKING. You need to provide a callback.
    # @param [String, Fixnum] groupId The genboree group id in which you want to change user's role
    # @param [String, Fixnum] userId The genboree user id for which you want to change the group role
    # @param [String] role Single letter role code. 'r' for read-only subscriber, 'w' for write-capable author, and 'o'
    #   for a owner-like administratior. Stored in the 'userGroupAccess' column.
    # @yieldparam [Hash<Symbol,Object>] results Your callback is called once the results are ready.
    #   Your code will be called with a single arg--a hash that has one of 2 keys:
    #   @option results [Array<Hash>] :count The rows-changed count. Should be 1, else OH NO.
    #   @option results [Exception] :err An exception that occurred.
    def roleUpdate(groupId, userId, role, &callback)
      cb = (block_given? ? Proc.new : callback) # will use saferRackProc() in fieldUpdat
      return fieldUpdate(groupId, userId, 'userGroupAccess', role, &cb )
    end

    # Change a specific field for genboree group.
    # @note NON-BLOCKING. You need to provide a callback.
    # @param [String, Fixnum] groupId The genboree group id in which you want to change a usergroup field
    # @param [String, Fixnum] userId The genboree user id for which you want to change a usergroup field
    # @param [String] field The field in the usergroup record to change. Cannot be 'name' nor 'groupName' nor 'groupId'.
    # @param [String] value The new value for field. Note that no value can be nil. Many fields like the name also cannot be blank and
    #   some others may have additional constraints
    # @yieldparam [Hash<Symbol,Object>] results Your callback is called once the results are ready.
    #   Your code will be called with a single arg--a hash that has one of 2 keys:
    #   @option results [Array<Hash>] :count The rows-changed count.
    #   @option results [Exception] :err An exception that occurred. Will be an ArgumentError if the field is unknown,
    #   or if field is unchangeable, or if userGroupAccess (role) is not one of 'r', 'w', 'o'
    def fieldUpdate(groupId, userId, field, value, &callback)
      retVal = true
      field = field.to_s.strip
      field = COLUMN_ALIASES[field] if( COLUMN_ALIASES[field] )
      value = value.to_s.strip
      cb = ( block_given? ? saferRackProc( &Proc.new ) : saferRackProc( &callback ) )
      argErrMsg = false
      # No-go decisions
      if( cb )
        if( !COLUMNS.key?(field) )
          argErrMsg = "ERROR: No such column #{field.inspect} in usergroup table."
        elsif( !COLUMNS[field] )
          argErrMsg = "ERROR: Cannot change #{field.inspect} for existing usergroup records."
        elsif( field == 'userGroupAccess' and !['r', 'w', 'o'].include?(value) )
          argErrMsg = "ERROR: the role code must be one of the letters 'r', 'w', 'o'; not #{role.inspect}."
        end

        if( !argErrMsg )
          updateColumnsByFieldAndValue( TABLE, { field => value }, { 'groupId' => groupId, 'userId' => userId }, :and) { |results|
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

    # "Upsert" - update existing record / insert new record. Given a groupId, userId, role, plus values for the other record fields,
    #   either insert a new record for that user-group if it doesn't exist (remember groupId is autoincrement and thus not
    #   provided here) OR if the user-group already exists then update all its column values to be those provided.
    # Thus you can use this to generate NEW GENBOREE GROUP, OR to update 'description' for an EXISTING GENBOREE USER.
    # @note Using this to update just 1 field like 'description' is not very smart. There are some dedicated update
    #   methods for some common fields as well as the flexible {#fieldUpdate} method that can update any of the valid fields.
    # @note NON-BLOCKING. You need to privde a callback.
    # @param [String, Fixnum] groupId The genboree group id for which you want to create/update user's membership info
    # @param [String, Fixnum] userId The genboree user id for which you want to create/update the group membership info
    # @param [String, Symbol] role Either the single letter role code or a Symbol correspoinding to a role.
    #   'r'  or :subscriber for read-only subscriber ; 'w' or :author for write-capable author ; or 'o' or :administrator
    #   for a owner-like administratior. Stored in the 'userGroupAccess' column.
    # @param [Fixnum] permissionBits Optional. Default 0. Set the permission bits number if you know about special cases (infrequent).
    # @yieldparam [Hash<Symbol,Object>] results Your callback is called once the results are ready.
    #   Your code will be called with a single arg--a hash that has one of 2 keys:
    #   @option results [Array<Hash>] :count The rows-changed count.
    #   @option results [Exception] :err An exception that occurred. Will be an ArgumentError if the field is unknown,
    #   or if field is unchangeable, or if userGroupAccess (role) is not one of 'r', 'w', 'o'
    def upsert(groupId, userId, role, permissionBits=0, &callback)
      retVal = true
      role = ( role.is_a?(String) ? role.to_s.strip : self.class::ROLES2MODES[role] )
      cb = ( block_given? ? saferRackProc( &Proc.new ) : saferRackProc( &callback ) )
      argErrMsg = false
      # No-go decisions
      if( cb )
        if( !['r', 'w', 'o'].include?(role) )
          argErrMsg = "ERROR: the role code must be one of the letters 'r', 'w', 'o'; not #{role.inspect}."
        elsif( !permissionBits.is_a?(Fixnum) or !(permissionBits >= 0) )
          argErrMsg = "ERROR: permissionBits must be a positive Fixnum. Why are you messing with it anyway?"
        end

        if( !argErrMsg )
          identCols = [ 'groupId', 'userId' ]
          col2val = {
            'groupId'         => groupId,
            'userId'          => userId,
            'userGroupAccess' => role,
            'permissionBits'  => permissionBits
          }
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
          customErrorViaCallback( ArgumentError, argErrMsg, &cb )
          retVal = false
        end
      else
        customErrorViaCallback( ArgumentError, "ERROR: you must supply a callback method by providing a code block (anonymous block or via &arg)", &cb )
        retVal = false
      end
      return retVal
    end

    # Get the usergroup table record for userGroupId.
    # @note You should NOT be calling this directly. Use one of the methods above.
    # @note Only intended to be used in non-blocking mode.
    # @param [String] userGroupId The userGroupId of the group of interest.
    # @return [Array, nil] Should be @true@ and your callback block/Proc will be called with a results Hash (see below).
    # @yieldparam [Hash<Symbol,Object>] results In async / non-blocking mode, your callback is called once the results are ready.
    #   Your code will be called with a single arg--a hash that has one of 2 keys:
    #   @option results [Array<Array>] :rows The output rows.
    #   @option results [Exception] :err An exception that occurred.
    def userGroupRecById( userGroupId, opts={}, &callback )
      retVal = true
      cb = ( block_given? ? saferRackProc( &Proc.new ) : saferRackProc( &callback ) )

      # No-go decisions
      if( cb )
        selectByFieldWithMultipleValues( TABLE, 'userGroupId', [userGroupId]) { |results|
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

    # Get the usergroup table record for groupId + userId.
    # @note You should NOT be calling this directly. Use one of the methods above.
    # @note Only intended to be used in non-blocking mode.
    # @param [String, Fixnum] groupId The genboree group id for which you want to get user's membership info
    # @param [String, Fixnum] userId The genboree user id for which you want to get the group membership info
    # @return [Array, nil] Should be @true@ and your callback block/Proc will be called with a results Hash (see below).
    # @yieldparam [Hash<Symbol,Object>] results In async / non-blocking mode, your callback is called once the results are ready.
    #   Your code will be called with a single arg--a hash that has one of 2 keys:
    #   @option results [Array<Array>] :rows The output rows.
    #   @option results [Exception] :err An exception that occurred.
    def userGroupRecByGroupAndUserId( groupId, userId, opts={}, &callback )
      retVal = true
      cb = ( block_given? ? saferRackProc( &Proc.new ) : saferRackProc( &callback ) )

      # No-go decisions
      if( cb )
        col2val = { 'groupId' => groupId, 'userId' => userId }

        selectByFieldValueMap(TABLE, col2val, :and) { |results|
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
    
    # ----------------------------------------------------------------
    # HELPERS - meant for internal use but not private in case there is utility for
    #   tightly-coupled classes.
    # ----------------------------------------------------------------

    # Try to reload the @rec using the info provided when object was initialized.
    # @return [true] In both blocking and non-blocking mode, this method returns true if the reload attempt completes.
    #   You can interrogate this object--in limited ways if blocking--for data, if any was found.
    # @yieldparam [Hash<Symbol,Object>] results Your callback is called once the results are ready.
    #   Your code will be called with a single arg--a hash that has one of 2 keys:
    #   @option results [Array<Hash>] :rows The output rows.
    #   @option results [Exception] :err An exception that occurred.
    def reload(&callback)
      cb = ( block_given? ? saferRackProc( &Proc.new ) : saferRackProc( &callback ) )
      @rec = nil
      if(cb) # Then NON-BLOCKING mode
        # Use tableRec(), which is non-blocking mode only and does right thing.
        tableRec(&callback)
        retVal = true
      else
        customErrorViaCallback( ArgumentError, "ERROR: you must supply a callback method by providing a code block (anonymous block or via &arg)", &cb )
        retVal = false
      end
      return retVal
    end

    private

    # Private constructor. Instantiate via userGroupId.
    # @note Meant to be called by the public factory constructor methods.
    # @param [Hash] rackEnv The Rack env hash.
    # @param [Hash{Symbol,Object}] opts A Hash with one of two key combinations to instantiate the object,
    #   and optionally a :dbHost key if you know the MySQL instance host to connect to (else GbApi::GbAuthHelper
    #   will be created and asked for the appropriate host info).
    #   @options opts [Fixnum] :userGroupId The genboree group id (row id). Cannot be used with :groupId and/or :userId
    #   @options opts [String] :groupId The genboree group groupId number ; MUST be used with :userId as well
    #   @options opts [String] :userId The genboree user userId number ; MUST be used with :groupId as well
    #   @options opts [String] :dbHost The MySQL instance host to connect to, if known. If not {GbApi::GbAuthHelper}
    #     will be instantiated to answer this.
    # @raise ArgumentError If you provide values for more than one of, or none of, :name :userGroupId
    def initialize( rackEnv, opts={ :dbHost => host } )
      # Options
      methodInfo = METHOD_INFO[__method__]
      opts = methodInfo[:opts].merge(opts)

      @objFor = { :userGroupId => opts[:userGroupId], :groupId => opts[:groupId], :userId => opts[:userId] }
      unless( ( @objFor.values.compact.size == 1 and !@objFor[:userGroupId].to_s.blank? ) or
              ( @objFor.values.compact.size == 2 and !@objFor[:groupId].to_s.blank? and !@objFor[:userId].to_s.blank? ) )
        raise ArgumentError, "ERROR: Must provide one of two valid cases for opts Hash: either just a value for :userGroupId key, or both a value for :groupId plus a value for :userId. @objFor was: #{@objFor.inspect}"
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

    # Update the state of this object from a result set--generally from a lookup query. If results empty or
    #   or invalid (no record found or perhaps error) then update state appropriately.
    # @note Upon updating from actual row/record, the @@objFor@ instance variable will change to contain the *userGroupId*
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
          @rec = rec
          # Switch from however initialized to userGroupId based reloading (in case of update or other changes)
          @objFor = { :userGroupId => fieldValue('userGroupId'), :groupId => nil, :userId => nil }
        else # no rec found
          # Leave objFor unchanged, since no better info available
          @rec = nil
        end
        retVal = @rec
      end
      return retVal
    end
  end
end
