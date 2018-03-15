require 'mysql2'
require 'mysql2/em'
require 'brl/db/dbrc'

module GbDb

  # Encapsulates key access to the Genboree main MySQL database for the
  #  Genboree instance providing authentication services to this Redmine.
  #  Primarily the 'genboreeuser' table.
  #
  # @note The focus of this class is stuff *directly* related to a *specific* genboree user login.
  #   Not even 'all users' or sets of users stuff. Don't pollute this with stuff that mainly
  #   concerned with other tables or concerns. Make a new class.
  class GbUser < GbDb::DbConnection
    include GbTableEntity

    # No calling new(). Use a factory method to get instance.
    private_class_method :new

    TABLE = 'genboreeuser'
    COLUMNS = {
      'userId' => false,
      'name' => false,
      'password' => true,
      'firstName' => true,
      'lastName' => true,
      'institution' => true,
      'email' => true,
      'phone' => true
    }
    COLUMN_ALIASES = {
      'recId' => 'userId',
      'login'  => 'name'
    }
    GB2RM_COL_MAP = {
      'email'     => 'mail',
      'firstName' => 'firstname',
      'lastName'  => 'lastname'
    }
    # The names of this entity can differ by case alone.
    CASE_SENSITIVE_NAME = false

    METHOD_INFO = {
      :initialize => {
        :opts => { :login => nil, :email => nil, :userId => nil, :dbHost => nil, :caseSensitive => self::CASE_SENSITIVE_NAME, :emCompliant => true }
      },
      :byLogin => {
        :opts => { :caseSensitive => self::CASE_SENSITIVE_NAME, :emCompliant => true }
      },
      :byUserId => {
        :opts => { :caseSensitive => self::CASE_SENSITIVE_NAME, :emCompliant => true }
      },
      :byEmail => {
        :opts => { :caseSensitive => self::CASE_SENSITIVE_NAME, :emCompliant => true }
      },
      :create => {
        :opts => { :createOwnGroup => true, :caseSensitive => self::CASE_SENSITIVE_NAME, :emCompliant => true }
      }
    }

    # Use metaclass to let GbTableEntity method get info and call CLASS "instance" methods
    class << self
      attr_accessor :classMethodAliases
      # GbTableEntity expects this class to have some methods that can be used for generic
      #   byId or byName, if we haven't named them that already. If not, map them here.
      GbUser.classMethodAliases = {
        :byId   => :byUserId,
        :byName => :byLogin
      }
    end

    attr_reader :gbAuthHelper, :authHost
    attr_reader :warnings

    # Factory instantiator. Instantiate for known genboree login.
    # @note The BLOCKING mode support is present here for backward compatibility only. It will not carry forward
    #   to new methods for this class.
    # @param [Hash] rackEnv The Rack env hash.
    # @param [String] login The genboree login/account name.
    # @param [Hash{Symbol,Object}] opts Additional opts affecting the account or this object. If the MySQL instance host
    #   is known, it can be provided via the :dbHost key. Otherwise it will be looked up.
    #   @option opts [boolean] :caseSensitive Default true. Login is case-sensitive in most situations. Obvious
    #     exception is when creating a new user and first checking if already exists (should check case-insensitve)
    #     to avoid confusing logins that differ only by case...probably user re-registration error. So can use this to override.
    #   @options opts [String] :dbHost The MySQL instance host to connect to, if known. If not {GbApi::GbAuthHelper}
    #     will be instantiated to answer this.
    # @return [GbDb::GbUser] In BLOCKING mode, returns the instance. In NON-BLOCKING mode, your callback
    #   will be called with a Hash that contains the instance or error information (see below)
    # @yieldparam [Hash<Symbol,Object>] results In NON-BLOCKING mode, your callback is called once the instance is created
    #   and any available login info is retrieved. Your code will be called with a single arg--a hash that has one of 2 keys:
    #   @option results [Array<Hash>] :obj The instance of this class.
    #   @option results [Exception] :err An exception that occurred.
    # @todo Remove the fallback to User.current as it is not async-safe.
    def self.byLogin( rackEnv, login=(rackEnv[:currRmUser] ? rackEnv[:currRmUser].login : User.current.login), opts={}, &callback )
      # Options
      methodInfo = METHOD_INFO[__method__]
      opts = methodInfo[:opts].merge(opts)

      rackCallback = rackEnv['async.callback'] rescue nil
      caseSense = ( ( opts and !opts[:caseSensitive].nil? ) ? opts[:caseSensitive] : self::CASE_SENSITIVE_NAME )
      cb = ( block_given? ? SaferRackProc.withRackCallback( rackCallback, &Proc.new ) : SaferRackProc.withRackCallback( rackCallback, &callback ) )
      newErr = nil
      # No-go decisions
      if( !login.blank? )
        # Instantiate empty
        begin
          obj = new( rackEnv, opts.merge( { :login => login, :email => nil, :userId => nil, :caseSensitive => caseSense } ) )
        rescue Exception => newErr
          obj = nil
        end
        # Use reload() to load details, if available
        if( cb ) # NON-BLOCKING
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
        msg = "ERROR: login argument cannot be blank"
        if( cb ) # NON-BLOCKING
          customErrorViaCallback( rackCallback, ArgumentError, msg, &cb )
          retVal = false
        else # BLOCKING
          raise ArgumentError, msg
        end
      end

      return retVal
    end

    # Factory instantiator. Instantiate for known genboree userId (row id).
    # @param [Hash] rackEnv The Rack env hash.
    # @param [Fixnum] userId The genboree login/account userId number.
    # @param [Hash{Symbol,Object}] opts Additional opts affecting the account or this object. If the MySQL instance host
    #   is known, it can be provided via the :dbHost key. Otherwise it will be looked up.
    #   @options opts [String] :dbHost The MySQL instance host to connect to, if known. If not {GbApi::GbAuthHelper}
    #     will be instantiated to answer this.
    # @return [GbDb::GbUser] Instance.
    # @yieldparam [Hash<Symbol,Object>] results Your callback is called once the instance is created.
    #   Your code will be called with a single arg--a hash that has one of 2 keys:
    #   @option results [Array<Hash>] :obj The instance of this class.
    #   @option results [Exception] :err An exception that occurred.
    def self.byUserId( rackEnv, userId, opts={}, &callback )
      # Options
      methodInfo = METHOD_INFO[__method__]
      opts = methodInfo[:opts].merge(opts)

      rackCallback = rackEnv['async.callback'] rescue nil
      cb = ( block_given? ? SaferRackProc.withRackCallback( rackCallback, &Proc.new ) : SaferRackProc.withRackCallback( rackCallback, &callback ) )
      newErr = nil
      # No-go decisions
      if( cb )
        if( !userId.blank? )
          # Instantiate empty
          begin
            obj = new( rackEnv, opts.merge( { :userId => userId, :login => nil, :email => nil } ) )
          rescue Exception => newErr
            obj = nil
          end
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
          else
            cb.call( { :err => newErr } )
            retVal = false
          end
        else
          customErrorViaCallback(rackCallback, ArgumentError, 'ERROR: userId argument cannot be blank', &cb )
          retVal = false
        end
      else
        customErrorViaCallback(rackCallback, ArgumentError, 'ERROR: you must supply a callback method by providing a code block (anonymous block or via &arg)', &cb )
        retVal = false
      end

      return retVal
    end

    # Factory instantiator. Instantiate for known genboree email. If there are more than
    #   1 accounts with same email address, the OLDEST will be used. Also a warning will be
    #   logged in @warnings and logged, since this will need to be fixed.
    # @note ONLY available in NON-BLOCKING mode.
    # @param [Hash] rackEnv The Rack env hash.
    # @param [String] email The email address for the genboree account.
    # @param [Hash{Symbol,Object}] opts Additional opts affecting the account or this object. If the MySQL instance host
    #   is known, it can be provided via the :dbHost key. Otherwise it will be looked up.
    #   @options opts [String] :dbHost The MySQL instance host to connect to, if known. If not {GbApi::GbAuthHelper}
    #     will be instantiated to answer this.
    # @return [GbDb::GbUser] Instance.
    # @yieldparam [Hash<Symbol,Object>] results Your callback is called once the instance is created.
    #   Your code will be called with a single arg--a hash that has one of 2 keys:
    #   @option results [Array<Hash>] :obj The instance of this class.
    #   @option results [Exception] :err An exception that occurred.
    def self.byEmail( rackEnv, email, opts={}, &callback )
      # Options
      methodInfo = METHOD_INFO[__method__]
      opts = methodInfo[:opts].merge(opts)

      rackCallback = rackEnv['async.callback'] rescue nil
      cb = ( block_given? ? SaferRackProc.withRackCallback( rackCallback, &Proc.new ) : SaferRackProc.withRackCallback( rackCallback, &callback ) )
      newErr = nil
      # No-go decisions
      if( cb )
        if( !email.blank? )
          # Instantiate empty
          begin
            # emails are not case sensitive, regardless of how login (entity name) is or isn't.
            obj = new( rackEnv, opts.merge( { :email => email, :login => nil, :userId => nil, :caseSensitive => false } ) )
          rescue Exception => err
            obj = nil
          end
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
          else
            cb.call( { :err => newErr } )
          end
        else
          customErrorViaCallback( rackCallback, ArgumentError, "ERROR: email argument cannot be blank", &cb )
          retVal = false
        end
      else
        customErrorViaCallback( rackCallback, ArgumentError, "ERROR: you must supply a callback method by providing a code block (anonymous block or via &arg)", &cb )
        retVal = false
      end

      return retVal
    end

    # "Create" - Create new record. Given a login, plus values for the other record fields,
    #   either insert a new record for that login if it doesn't exist.
    # Thus you can use this to generate NEW GENBOREE USER..
    # @note NON-BLOCKING. You need to privde a callback.
    # @param [Hash] rackEnv The Rack env hash.
    # @param [String] login The genboree login you wish to create or update.
    # @param [String] email The new email. Cannot be nil, blank, nor not-email-like.
    # @param [String] password The new password. Cannot be nil, blank, nor too short.
    # @param [String] firstName The new first name. Cannot be nil nor blank.
    # @param [String] lastName The new last name. Cannot be nil nor blank.
    # @param [String] institution The new institution.
    # @param [String] phone The new phone.
    # @param [Hash{Symbol,Object}] opts Optional. Hash to tweak creation behavior.
    # @option opts [boolean] :createOwnGroup Default=true. Upon successfully creating the user, ALSO
    #   create the user's specific group. Assumed by some older code such as Java/JSP code (during session
    #   authentication; needed for workbench). Group will have name like {login}_group. If already exists, then
    #   fallback of {login}_{userId}_group will be used. Only disable this in custom cases where you don't
    #   new some default auto-generated group because you're going to arrange to add them to some special
    #   group yourself.
    # @yieldparam [Hash<Symbol,Object>] results Your callback is called once the results are ready.
    #   Your code will be called with a single arg--a hash that has one of 2 keys:
    #   @option results [Array<Hash>] :count The rows-changed count.
    #   @option results [Exception] :err An exception that occurred.
    def self.create(rackEnv, login, email, password, institution, firstName, lastName, phone, opts={}, &callback)
      # Options
      methodInfo = METHOD_INFO[__method__]
      opts = methodInfo[:opts].merge(opts)

      rackCallback = rackEnv['async.callback'] rescue nil
      cb = ( block_given? ? SaferRackProc.withRackCallback( rackCallback, &Proc.new ) : SaferRackProc.withRackCallback( rackCallback, &callback ) )
      # No-go decisions
      if( cb )
        # Try to create new instance AND populate it from database (should not be able to populate)
        self.byName(rackEnv, login, opts) { |results|
          obj = results[:obj] rescue nil
          if( obj ) # then no sql error querying database etc, yay
            if( obj.userId.nil? ) # and no existing record for login, yay
              # But what about email address? Start enforcing unique email.
              opts[:caseSensitive] = false #  emails can't be case sensitive, regardless of CASE_SENSITIVE_NAME
              self.byEmail(rackEnv, email, opts) { |emailResults|
                obj = emailResults[:obj] rescue nil
                if( obj ) # then no seql error querying yay
                  if( obj.userId.nil? ) # then no existing record for email, yay
                    # Create via upsert...which due to the byName() will be an insert if it's done.
                    begin
                      upsertAccepted = obj.upsert(login, email, password, institution, firstName, lastName, phone ) { |upsertResults|
                        count = upsertResults[:count]
                        if(count and count > 0) # Then went as expected
                          # Are we to create the user-specific default group as well?
                          if( opts[:createOwnGroup] )
                            obj.createOwnGroup() { |grpResults|
                              grp = grpResults[:obj]
                              if( grp )
                                cb.call( { :obj => obj} )
                              else # own-group creation failed
                                err = grpResults[:err]
                                customErrorViaCallback( rackCallback, RuntimeError, "Appeared to have created user but failed to create the user-specific default group. Group creation error:\n  Error Class: #{err.class}\n    Error Msg: #{err.message.inspect}\n    Error Trace:\n#{err.backtrace.join("\n")}")
                              end
                            }
                          else # no, just the bare user (may not work with all Genboree services as-is!)
                            cb.call( { :obj => obj } )
                          end
                        else # Error? bad count?
                          if(count)
                            customErrorViaCallback( rackCallback, RuntimeError, "Insert of new record returned suspect rows-affected count of #{count.inspect}", &cb )
                          else # better be an :err
                            cb.call( upsertResults )
                          end
                        end
                      }
                    rescue => err # Our upsert() call was immediately rejected, pass the exception to dev callback
                      cb.call( { :err => err } )
                    end
                  else # not empty, already is a user record with that login
                    customErrorViaCallback( rackCallback, IndexError, "There is already a genboree user record with the email #{email.inspect}, cannot use this #{__method__.inspect} to create another!", &cb )
                  end
                else # Some error just querying for existing record via email!
                  cb.call( emailResults )
                end
              }
            else # not empty, already is a user record with that login
              customErrorViaCallback( rackCallback, IndexError, "There is already a genboree user record with the login #{login.inspect}, cannot use this #{__method__.inspect} to create another.", &cb )
            end
          else # Some error just querying for existing record via login!
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

    def exists?()
      return !self.userId.nil?
    end

    # Get the Redmine model-instance (entity) equivalent or nearest equivalent to this GbUser instance.
    # @note This instance must reflect an existing Genboree user, else an Exception will be returned; not intended
    #   to be used to create arbitrary Redmine user records that are not backed by a Genboree user. The Genboree user
    #   MUST have non-blank email, first name, AND last name to be valid.
    # @note Sub-classes should implement this where sensible. By default will raise a NotImplemented error, which
    #   may be appropriate when there is no clear 1:1 mapping between Genboree and Redmine (e.g. consider GbUserGroup)
    # @return [boolean] If your async callback has been accepted and will be called with a Hash argument with one of the two
    #   uniform keys, :obj or :err (see below)
    # @yieldparam [Hash<Symbol,Object>] results In NON-BLOCKING mode, your callback is called once the User instance is retrieved.
    #   Your code will be called with a single arg--a hash that has one of 2 keys:
    #   @option results [User] :obj The instance of the Redmine User model class for the login.
    #   @option results [Exception] :err An exception or problem that occurred.
    def redmineEntity( opts={}, &callback )
      cb = ( block_given? ? saferRackProc( &Proc.new ) : saferRackProc( &callback ) )
      # No-go decisions
      if( cb )
        self.validateInfo( :min4shadowing ) { |result|
          if( result[:obj].is_a?( GbDb::GbUser ) )
            user = User.find_by_login( self.login ) rescue nil
            #$stderr.debugPuts(__FILE__, __method__, 'DEBUG', "Redmine User object found via login for #{self.login.inspect} is a User class? #{user.is_a?(User)} ; type is: #{user.type.inspect rescue nil} ; details:\n\n#{user.inspect}\n\n")
            if( user.is_a?( User ) )
              if( user.type != 'AnonymousUser ')
                if( user.login == self.login ) # Then they match, even by case
                  cb.call( { :obj => user } )
                else
                  cb.call( { :err => IndexError.new("Found a matching Redmine user record for this Genboree user, but the login differs by case (Redmine login: #{user.login.inspect}). This is not allowed and required admin assistance to resolve.") } )
                end
              else
                cb.call( { :err => IndexError.new("This user appears to be equivalent to the (a) Redmine AnonymousUser. That makes no sense for what is supposed to be a valid existing Genboree user record.") } )
              end
            else
              cb.call( { :err => IndexError.new( "No Redmine user found for login #{self.login.inspect}." ) } )
            end
          else
            cb.call( result )
          end
        }
        retVal = true
      else
        customErrorViaCallback( ArgumentError, "ERROR: you must supply a callback method by providing a code block (anonymous block or via &arg)", &cb )
        retVal = false
      end

      return retVal
    end

    # Create the matching Redmine entity record. For GbUser, this creates the Redmine shadow-record with
    #   appropriate info for AuthSource, etc.
    # @note In addition to this instance being backed by an actual Genboree user record, several core/key fields MUST be
    #   sensible and filled it, else an error will be returned to your callback.
    # @note Additionally, certain internal fields (such as auth_source_id) will be populated automatically with appropriate
    #   values, and there is no facility for using your own possibly invalid values.
    # @note Of course, there must be no existing Redmine record with sample login nor email.
    # @note Presumes that there is a SINGLE AuthSource where these are both true: :type == 'AuthSourceGenboree' AND :name == 'Genboree'
    # @return [boolean] If your async callback has been accepted and will be called with a Hash argument with one of the two
    #   uniform keys, :obj or :err (see below)
    # @yieldparam [Hash<Symbol,Object>] results In NON-BLOCKING mode, your callback is called once the User instance is retrieved.
    #   Your code will be called with a single arg--a hash that has one of 2 keys:
    #   @option results [User] :obj The instance of the newly Redmine User model class for the login.
    #   @option results [Exception] :err An exception or problem that occurred.
    def createRedmineEntity( opts={}, &callback )
      cb = ( block_given? ? saferRackProc( &Proc.new ) : saferRackProc( &callback ) )
      # No-go decisions
      if( cb )
        # Check that we can find correct AuthSource right away (it's rails...blocking)
        gbAuthSrcs = AuthSourceGenboree.where( :name => "Genboree" )
        gbAuthSrcId = gbAuthSrcs.first.id rescue nil
        if( gbAuthSrcId and gbAuthSrcs.size == 1 )
          self.validateInfo( :min4shadowing ) { |result|
            if( result[:obj].is_a?( GbDb::GbUser ) )
              user = User.find_by_login( self.login ) rescue nil
              if( user.is_a?( User ) ) # WTH? Already appears to be an existing record matching this user?
                cbArg = { :err => IndexError.new( "There is already a Redmine users record that matches this Genboree record! Check for #{self.login.inspect}." ) }
              else # No redmine users record yet, as expected
                # Makes obj but doesn't save (need to run valid? first anyway, since there are constraint hooks in Model)
                # - Also, cannot use Hash to populate many of the "sensitive" fields; but can through accessor assignment
                user = User.new( { :firstname => self.firstName, :lastname => self.lastName, :mail => self.email } )
                # - Use accessors to set some of the "sensitive" fields
                user.login = self.login
                user.auth_source_id = gbAuthSrcId
                # - Valid, according to Redmine/Rails? If not will not proceed.
                if( user.valid? )
                  saved = user.save
                  if( saved )
                    cbArg = { :obj => user }
                  else
                    cbArg = { :err => RuntimeError.new("Something went wrong at last moment of saving new Redmine users record. Everything validated yet the Redmain/Rails User#save method returned #{saved.inspect} rather than simply 'true'. ") }
                  end
                else
                  cbArg = { :err => RuntimeError.new( "Redmine/Rails reports that the user is not valid (does not pass Model constraints & checks). Its validation routines complained about: #{user.errors.full_messages.inspect rescue '<<Could not even get usual errors list!>>'}" ) }
                end
              end
            else
              cbArg = result
            end

            cb.call( cbArg )
          }
          retVal = true
        else
          customErrorViaCallback( IndexError, "No AuthSourceGenboree records whose name is 'Genboree'. Can't create properly linked Redmine user record because auth_sources doesn't appear to have exactly 1 record whose type is 'AuthSourceGenboree' and whose name is 'Genboree'. Not normal set-up.", &cb )
          retVal = false
        end
      else
        customErrorViaCallback( ArgumentError, "ERROR: you must supply a callback method by providing a code block (anonymous block or via &arg)", &cb )
        retVal = false
      end

      return retVal
    end

    # Sync Genboree user information (from 'genboreeuser' table row) to corresponding Redmine User entity ('user' table row; User model).
    #   The following fields will be copied from the Genboree record to the corresponding Redmine record (see also the 'auth_sources'
    #   table record, as it lists this mapping as well): firstName [=>firstname], lastName [=>lastname],
    #   email [=> mail].
    # @note Only works if a valid Genboree record/row was found or created when creating this object.
    # @note Furthermore, there must *be* a corresponding Redmine record available (via User.find_by_login(self.login))
    #   already existing for this record; presumably created via {#createRedmineEntity} at some point previously.
    # @return [boolean] If your async callback has been accepted and will be called with a Hash argument with one of the two
    #   uniform keys, :obj or :err (see below)
    # @yieldparam [Hash<Symbol,Object>] results In NON-BLOCKING mode, your callback is called once the User instance is retrieved.
    #   Your code will be called with a single arg--a hash that has one of 2 keys:
    #   @option results [User] :obj The instance of the newly Redmine User model class for the login.
    #   @option results [Exception] :err An exception or problem that occurred.
    def syncToRedmine( &callback )
      cb = ( block_given? ? saferRackProc( &Proc.new ) : saferRackProc( &callback ) )

      # No-go decisions
      if( cb )
        self.gbUserRec { |rs|
          cbArg = nil
          rows = rs[:rows] rescue nil
          if( rows.is_a?(Array) )
            if( !rows.empty? )
              redmineEntity { |rm| # This also does some validation and checking to make sure things are sensible
                if( rm and rm[:obj].is_a?( User ) )
                  # Sync Remdine User obj with Genboree info
                  rmUser = rm[:obj]
                  self.class::GB2RM_COL_MAP.each_key { |gbCol|
                    rmCol = self.class::GB2RM_COL_MAP[gbCol]
                    rmColAssign = :"#{rmCol}="
                    rmUser.send( rmColAssign, self.send(gbCol) )
                  }
                  rmUser.save
                  cbArg = { :obj => rmUser }
                else # bad ; hopefully :err
                  err = rm[:err] rescue nil
                  if( err )
                    cbArg = { :err => err }
                  else # serious/fundamental problem...make sure to log and tread carefully
                    cbArg = nil
                    customErrorViaCallback(RuntimeError, 'ERROR: unexpected error trying to retrieve corresponding Redmine User record, and no error details provided via standard mechanism. Likely an indicator of a bug, and should be brought to the attention of administrators.', &cb )
                  end
                end
              }
            else
              cbArg = { :err => RuntimeError.new("ERROR: there is no Genboree record to copy information from. Perhaps this is a new user which has not yet been saved? Or simply a login/email which doesn't correspond to a user record.") }
            end
          else
            err = rs[:err] rescue nil
            if( err )
              cbArg = { :err => err }
            else # serious/fundamental problem...make sure to log and tread carefully
              cbArg = nil
              customErrorViaCallback(RuntimeError, 'ERROR: unexpected error getting Genboree record and no error details provided via standard mechanism. Likely an indicator of a bug, and should be brought to the attention of administrators.', &cb )
            end
          end

          cb.call( cbArg ) if(cbArg)
          retVal = true
        }
      else
        customErrorViaCallback(ArgumentError, 'ERROR: you must supply a callback method by providing a code block (anonymous block or via &arg)', &cb )
        retVal = false
      end

      return retVal
    end

    # Get the genboreeuser row/record for the user as a Hash. If already retrieved, uses in-memory version.
    # @note ONLY works as non-blocking. Older BLOCKING approach not supported by this method.
    # @note For objects created via login, this employs the default case-sensitive mode of userRecByGbLogin
    # @yieldparam [Hash<Symbol,Object>] results Your callback is called once the results are ready.
    #   Your code will be called with a single arg--a hash that has one of 2 keys:
    #   @option results [Array<Hash>] :rows The output rows.
    #   @option results [Exception] :err An exception that occurred or was noticed.
    def gbUserRec(&callback)
      cb = ( block_given? ? saferRackProc( &Proc.new ) : saferRackProc( &callback ) )
      # No-go decisions
      if( cb )
        #$stderr.debugPuts(__FILE__, __method__, 'DEBUG', "@objFor: #{@objFor.inspect} ; @gbUserRec: #{@gbUserRec.inspect}")
        if(@gbUserRec)
          # Then we have already available, immediately call callback with it
          cb.call( { :rows => [ @gbUserRec ] } )
        else
          # Need to get it.
          if( !@objFor[:login].blank? )
            #$stderr.debugPuts(__FILE__, __method__, 'DEBUG', "using login")
            userRecByGbLogin(@objFor[:login], { :caseSensitive => @objFor[:caseSensitive] }, &cb )
          elsif( !@objFor[:email].blank? ) # !@email.blank?
            #$stderr.debugPuts(__FILE__, __method__, 'DEBUG', "using email")
            userRecByGbEmail(@objFor[:email], &cb )
          else # assume userId
            #$stderr.debugPuts(__FILE__, __method__, 'DEBUG', "using userId")
            userRecByGbUserId(@objFor[:userId], &cb )
          end
        end
        retVal = true
      else
        customErrorViaCallback( ArgumentError, "ERROR: you must supply a callback method by providing a code block (anonymous block or via &arg)", &cb )
        retVal = false
      end

      return retVal
    end
    alias_method :tableRec, :gbUserRec

    # Change password for existing genboree login.
    # @note NON-BLOCKING. You need to provide a callback.
    # @param [String] login The genboree login for which you have a new password.
    # @param [String] password The new password.
    # @yieldparam [Hash<Symbol,Object>] results Your callback is called once the results are ready.
    #   Your code will be called with a single arg--a hash that has one of 2 keys:
    #   @option results [Array<Hash>] :count The rows-changed count. Should be 1, else OH NO.
    #   @option results [Exception] :err An exception that occurred.
    def passwordUpdate(login, password, opts={}, &callback)
      cb = (block_given? ? Proc.new : callback) # will use saferRackProc() in fieldUpdate()
      return fieldUpdate(login, 'password', password, &cb )
    end

    # Change email for existing genboree login.
    # @note NON-BLOCKING. You need to provide a callback.
    # @param [String] login The genboree login for which you have a new email.
    # @param [String] email The new email.
    # @param [Hash{Symbol,Object}] opts Optional. Hash to tweak update behavior.
    #   @option opts [boolean] :syncToRedmine Default=false. After performing the update to Genboree,
    #     ALSO update the matching Redmine record (via {#syncToRedmine}). Requires EXISTING and COMPLIANT
    #     Redmine record is actually in place (else Exception will be passed through to your callback).
    # @yieldparam [Hash<Symbol,Object>] results Your callback is called once the results are ready.
    #   Your code will be called with a single arg--a hash that has one of 2 keys:
    #   @option results [Array<Hash>] :count The rows-changed count. Should be 1, else OH NO.
    #   @option results [Exception] :err An exception that occurred.
    def emailUpdate(login, email, opts={ :syncToRedmine => false }, &callback)
      cb = (block_given? ? Proc.new : callback) # will use saferRackProc() in fieldUpdate()
      return fieldUpdate(login, 'email', email, opts, &cb )
    end

    # Change institution for existing genboree login.
    # @note NON-BLOCKING. You need to provide a callback.
    # @param [String] login The genboree login for which you have a new password.
    # @param [String] institution The new institution.
    # @yieldparam [Hash<Symbol,Object>] results Your callback is called once the results are ready.
    #   Your code will be called with a single arg--a hash that has one of 2 keys:
    #   @option results [Array<Hash>] :count The rows-changed count. Should be 1, else OH NO.
    #   @option results [Exception] :err An exception that occurred.
    def institutionUpdate(login, institution, opts={}, &callback)
      cb = (block_given? ? Proc.new : callback)
      return fieldUpdate(login, 'institution', institution, &cb )
    end

    # Change a specific field for genboree login.
    # @note NON-BLOCKING. You need to provide a callback.
    # @note You'll get an ArgumentError at the :err key in your callback arg if the field is unknown, or if field is unchangeable,
    #   or if password and value is black or too short, or if email doesn't look even a little bit like an email address, or if
    #   the first/last name values are blank, etc. Also if try to change email to value already in use by a different email.
    # @param [String] login The genboree login for which you want to update some field's value.
    # @param [String] field The field in the genboreeuser record to change. Cannot be 'name' (i.e. the login) nor 'userId'.
    # @param [String] value The new value for field. Note that no value can be nil. Many fields like the name also cannot be blank and
    #   some others may have additional constraints (like email should look vaguely like an email; password should not be short)
    # @param [Hash{Symbol,Object}] opts Optional. Hash to tweak update behavior.
    #   @option opts [boolean] :syncToRedmine Default=false. After performing the update to Genboree,
    #     ALSO update the matching Redmine record (via {#syncToRedmine}). Requires EXISTING and COMPLIANT
    #     Redmine record is actually in place (else Exception will be passed through to your callback).
    # @yieldparam [Hash<Symbol,Object>] results Your callback is called once the results are ready.
    #   Your code will be called with a single arg--a hash that has one of 2 keys:
    #   @option results [Array<Hash>] :count The rows-changed count.
    #   @option results [Exception] :err An exception that occurred.
    def fieldUpdate(login, field, value, opts={ :syncToRedmine => false }, &callback)
      retVal = true
      field = field.to_s.strip
      value = value.to_s.strip
      cb = ( block_given? ? saferRackProc( &Proc.new ) : saferRackProc( &callback ) )
      argErrMsg = false
      # No-go decisions
      if( cb )
        if( !COLUMNS.key?(field) )
          argErrMsg = "ERROR: No such column #{field.inspect} in genboreeuser table."
        elsif( !COLUMNS[field] )
          argErrMsg = "ERROR: Cannot change #{field.inspect} for existing user records."
        elsif( field == 'password' and (value.blank? or value.size < 6 ) )
          argErrMsg = "ERROR: Passwords can't be blank nor shorter than 6 chars."
        elsif( field == 'email' and value !~ /^.+@.+$/ )
          argErrMsg = "ERROR: Email address #{email.inspect} doesn't look even minimally like an email address."
        elsif( value.blank? and ( field == 'firstName' or field == 'lastName' ) )
          argErrMsg = "ERROR: The column #{field.inspect} cannot have a blank value."
        end

        if( !argErrMsg )
          # We need to treat 'email' special in order to check it.
          # - first save what we plan on doing if things are ok:
          updateProc = Proc.new {
            updateColumnsByFieldAndValue( TABLE, { field => value }, { 'name' => login }, :and, { :smartBinMode => self.class::CASE_SENSITIVE_NAME } ) { |results|
              if( results[:count] )
                # If things went ok, need to do a reload() to refresh data in this object
                reload() { |reloadResults|
                  if( reloadResults[:err] )
                    err = reloadResults[:err]
                    msg = "Update appears to have succeeded, but trying to reload the record to refresh this object seems to have failed."
                    $stderr.debugPuts(__FILE__, __method__, 'WARNING', "#{msg}.\n    Error class: #{err.class rescue nil}\n    Error Msg: #{err.message rescue nil}\n    Error Trace:\n#{err.backtrace.join("\n") rescue nil}")
                  end
                  # Are we asked to sync with equivalent Redmine record?
                  if( opts[:syncToRedmine] )
                    syncToRedmine() { |syncResults|
                      if( syncResults and syncResults[:obj].is_a?(User) ) # Then went ok ; return results as planned
                        cb.call( results )
                      else
                        err = syncResults[:err] rescue nil
                        if( err )
                          cb.call( { :err => err  } )
                        else # serious/fundamental problem...make sure to log and tread carefully
                          cbArg = nil
                          customErrorViaCallback(RuntimeError, 'ERROR: unexpected error trying to sync Genboree record with Redmine record, and no error details provided via standard mechanism. Likely an indicator of a bug, and should be brought to the attention of administrators.', &cb )
                        end
                      end
                    }
                  else # no sync, just call dev callback
                    cb.call( results )
                  end
                }
              else # update didn't go ok so no reload
                cb.call( results )
              end
            }
          }

          if(field == 'email')
            self.class.byEmail(@rackEnv, value) { |emailResults|
              obj = emailResults[:obj] rescue nil
              if( obj ) # then no seql error querying yay
                if( obj.userId.nil? ) # then no existing record for email, yay
                  updateProc.call( )
                else # not empty, already is a user record with that login
                  customErrorViaCallback( IndexError, "There is already a genboree user record with the email #{value.inspect}, cannot use this to create another!", &cb )
                end
              else # Some error just querying for existing record via email!
                cb.call( emailResults )
              end
            }
          else # not email, just proceed as planned
            updateProc.call( )
          end
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

    # "Upsert" - update existing record / insert new record. Given a login, plus values for the other record fields,
    #   either insert a new record for that login if it doesn't exist (remember userId is autoincrement and thus not
    #   provided here) OR if the login already exists then update all its column values to be those provided.
    # Thus you can use this to generate NEW GENBOREE USER,  OR to update 'password' and/or 'firstName' and/or 'lastName'
    #   and/or 'institution' and/or 'email' and/or 'phone' for an EXISTING GENBOREE USER.
    # @note Using this to update just 1 field like 'password' or email is not very smart. There are some dedicated update
    #   methods for some common fields as well as the flexible {#fieldUpdate} method that can update any of the valid fields.
    # @note NON-BLOCKING. You need to privde a callback.
    # @param [String] login The genboree login you wish to create or update.
    # @param [String] email The new email. Cannot be nil, blank, nor not-email-like.
    # @param [String] password The new password. Cannot be nil, blank, nor too short.
    # @param [String] firstName The new first name. Cannot be nil nor blank.
    # @param [String] lastName The new last name. Cannot be nil nor blank.
    # @param [String] institution The new institution.
    # @param [String] phone The new phone.
    # @param [Hash{Symbol,Object}] opts Optional. Hash to tweak creation/update behavior.
    #   @option opts [boolean] :syncToRedmine Default=false. After performing the update to Genboree,
    #     ALSO update the matching Redmine record (via {#syncToRedmine}). Requires EXISTING and COMPLIANT
    #     Redmine record is actually in place (else Exception will be passed through to your callback).
    # @yieldparam [Hash<Symbol,Object>] results Your callback is called once the results are ready.
    #   Your code will be called with a single arg--a hash that has one of 2 keys:
    #   @option results [Array<Hash>] :count The rows-changed count.
    #   @option results [Exception] :err An exception that occurred.
    # @raise ArgumentError If you don't supply a callback method which can take the results, or if the field is unknown,
    #   or if field is unchangeable, or if password and value is black or too short, or if email doesn't look even a little
    #   bit like an email address, or if the first/last name values are blank, etc.
    def upsert(login, email, password, institution, firstName, lastName, phone, opts={ :syncToRedmine => false }, &callback)
      retVal = true
      email = email.to_s.strip
      password = password.to_s.strip
      institution = institution.to_s.strip
      firstName = firstName.to_s.strip
      lastName = lastName.to_s.strip
      phone = phone.to_s.strip

      cb = ( block_given? ? saferRackProc( &Proc.new ) : saferRackProc( &callback ) )
      argErrMsg = false
      # No-go decisions
      if( cb )
        if( password.blank? or password.size < 6  )
          argErrMsg = "ERROR: Passwords can't be blank nor shorter than 6 chars."
        elsif( email !~ /^.+@.+$/ )
          argErrMsg = "ERROR: Email address #{email.inspect} doesn't look even minimally like an email address."
        elsif( firstName.blank? or lastName.blank? )
          argErrMsg = "ERROR: The firstName and lastName columns cannot have blank values."
        end

        if( !argErrMsg )
          # We need to treat 'email' special in order to check it.
          # Email value is ok is (a) it's not in use by anyone (and _posssibly_ we'll be inserting a new record,
          #   but not necessarily) ; or (b) it's in use by this user record specifically (which obviously we are about to update).
          self.class.byEmail(@rackEnv, email) { |emailResults|
            obj = emailResults[:obj] rescue nil
            if( obj ) # then no sql error querying yay
              if( obj.userId.nil? or obj.login.downcase == login.downcase ) # then no existing record for email or the existing record is THIS one, yay
                identCols = [ 'name' ]
                col2val = {
                  'name'        => login,
                  'password'    => password,
                  'firstName'   => firstName,
                  'lastName'    => lastName,
                  'institution' => institution,
                  'email'       => email,
                  'phone'       => phone
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
                      # Are we asked to sync with equivalent Redmine record?
                      if( opts[:syncToRedmine] )
                        syncToRedmine() { |syncResults|
                          if( syncResults and syncResults[:obj].is_a?(User) ) # Then went ok ; return results as planned
                            cb.call( results )
                          else
                            err = syncResults[:err] rescue nil
                            if( err )
                              cb.call( { :err => err  } )
                            else # serious/fundamental problem...make sure to log and tread carefully
                              cbArg = nil
                              customErrorViaCallback(RuntimeError, 'ERROR: unexpected error trying to sync Genboree record with Redmine record, and no error details provided via standard mechanism. Likely an indicator of a bug, and should be brought to the attention of administrators.', &cb )
                            end
                          end
                        }
                      else # no sync, just call dev callback
                        cb.call( results )
                      end
                    }
                  else # update didn't go ok so no reload
                    cb.call( results )
                  end
                }
              else # not empty, already is a user record with that login
                customErrorViaCallback( IndexError, "There is already a different genboree user record with the email #{email.inspect}, cannot use it for #{login.inspect}!", &cb )
              end
            else # Some error just querying for existing record via email!
              cb.call( emailResults )
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

    # Get all the externalHostAccess table records for a genboree user, given the user's genboree userId number.
    # @note By default, for backward compatibility, this is a SYNCHRONOUS / BLOCKING call! But has newer async option.
    # @todo Update async API libs to use async-mode even for this step.
    # @param [Fixnum] userId The genboree user id number.
    # @return [Array<Array>, nil, Boolean] In non-async / blocking mode, the return is an Array of all externalHostAccess rows,
    #   possibly empty, or nil if error. In async / non-blocking mode, the return should be @true@ and your callback block/Proc
    #   will be called with a results Hash (see below).
    # @yieldparam [Hash<Symbol,Object>] results In async / non-blocking mode, your callback is called once the results are ready.
    #   Your code will be called with a single arg--a hash that has one of 2 keys:
    #   @option results [Array<Array>] :rows The output rows.
    #   @option results [Exception] :err An exception that occurred.
    def allExternalHostInfoByGbUserId(userId=self.userId, opts={}, &callback )
      retVal = nil
      cb = ( block_given? ? saferRackProc( &Proc.new ) : saferRackProc( &callback ) )
      if(cb) # NON-BLOCKING
        selectByFieldWithMultipleValues( 'externalHostAccess', 'userId', [userId], &cb )
        retVal = true
      else # BLOCKING
        sql = "SELECT * FROM externalHostAccess WHERE userId = #{Mysql2::Client.escape(userId.to_s)}"
        client = nil
        retVal = nil
        begin
          client = getMysql2Client()
          recs = client.query(sql)
          retVal = recs.entries
        rescue => err
          $stderr.puts err
        ensure
          client.close rescue nil
        end
      end

      return retVal
    end

    # Get the genboreeuser table record for login.
    # @note You should NOT be calling this directly. Use one of the methods above. Only here for backward compatibility.
    # @note THIS METHOD SUPPORTS non-EM / SYNCHRONOUS OPERATION [for backward compatibiliyt] AND EM-based ASYNCHRONOUS DB QUERYING.
    #   The way results are returned is slightly different if use the async version.
    # @param [String] login OPTIONAL. The login, typically the current Redmine login which is default.
    # @param [Hash{Symbol,Object}] opts Additional opts affecting the account or this object.
    #   @option opts [boolean] :caseSensitive Default true. Login is case-sensitive in most situations. Obvious
    #     exception is when creating a new user and first checking if already exists (should check case-insensitve
    #     to avoid confusing logins that differ only by case...probably user re-registration error). So can use this to override.
    # @return [Array, nil] In non-async / blocking mode, the return is the genboreeuser row matching login or nil if not found.
    #   In async / non-blocking mode, the return should be @true@ and your callback block/Proc will be called with a results
    #   Hash (see below).
    # @yieldparam [Hash<Symbol,Object>] results In async / non-blocking mode, your callback is called once the results are ready.
    #   Your code will be called with a single arg--a hash that has one of 2 keys:
    #   @option results [Array<Array>] :rows The output rows.
    #   @option results [Exception] :err An exception that occurred.
    # @todo Remove the fallback to User.current as it is not async-safe.
    def userRecByGbLogin( login=(@rackEnv[:currRmUser] ? @rackEnv[:currRmUser].login : User.current.login), opts= { :caseSensitive => self.class::CASE_SENSITIVE_NAME }, &callback )
      retVal = nil
      caseSense = opts[:caseSensitive]
      cb = ( block_given? ? saferRackProc( &Proc.new ) : saferRackProc( &callback ) )
      if(cb)
        selectByFieldWithMultipleValues(TABLE, 'name', [login], { :smartBinMode => caseSense } ) { |results|
          # Save the retrieved record, if any
          setStateFromResults( results )
          cb.call( results )
        }
        retVal = true
      else
        results = userRecsByGbLogin(login, opts)
        retVal = setStateFromResults( results )
      end
      return retVal
    end

    # Get the genboreeuser table record for userId.
    # @note You should NOT be calling this directly. Use one of the methods above. Only here for backward compatibility.
    # @note Only intended to be used in non-blocking mode.
    # @param [String] userId The userId of the user of interest.
    # @return [Array, nil] Should be @true@ and your callback block/Proc will be called with a results Hash (see below).
    # @yieldparam [Hash<Symbol,Object>] results In async / non-blocking mode, your callback is called once the results are ready.
    #   Your code will be called with a single arg--a hash that has one of 2 keys:
    #   @option results [Array<Array>] :rows The output rows.
    #   @option results [Exception] :err An exception that occurred.
    def userRecByGbUserId( userId, opts={}, &callback )
      retVal = true
      cb = ( block_given? ? saferRackProc( &Proc.new ) : saferRackProc( &callback ) )

      # No-go decisions
      if(cb)
        selectByFieldWithMultipleValues(TABLE, 'userId', [userId]) { |results|
          # Save the retrieved record, if any, and use it to update key object state
          setStateFromResults(results )
          cb.call( results )
        }
      else
        customErrorViaCallback( ArgumentError, "ERROR: you must supply a callback method by providing a code block (anonymous block or via &arg)", &cb )
        retVal = false
      end

      return retVal
    end

    # Get the genboreeuser table record via a user's email address.
    # @note You should NOT be calling this directly. Use one of the methods above. Only here for backward compatibility.
    # @note Only intended to be used in non-blocking mode.
    # @param [String] email The email of the user of interest. If more than one genboree user account has the same address
    #   [which is BAD and will be deprecated] then the OLDEST (lowest userId) ONE IS USED.
    # @return [Array, nil] Should be @true@ and your callback block/Proc will be called with a results
    #   Hash (see below).
    # @yieldparam [Hash<Symbol,Object>] results In async / non-blocking mode, your callback is called once the results are ready.
    #   Your code will be called with a single arg--a hash that has one of 2 keys:
    #   @option results [Array<Array>] :rows The output rows.
    #   @option results [Exception] :err An exception that occurred.
    def userRecByGbEmail( email, opts={}, &callback )
      retVal = nil
      cb = ( block_given? ? saferRackProc( &Proc.new ) : saferRackProc( &callback ) )

      # No-go decisions
      if(cb)
        selectByFieldWithMultipleValues( TABLE, 'email', [email], { :orderBy => { 'userId' => :asc } } ) { |results|
          # Save the retrieved record, if any, and use it to update key object state
          setStateFromResults( results )
            cb.call( results )
        }
      else
        customErrorViaCallback( ArgumentError, "ERROR: you must supply a callback method by providing a code block (anonymous block or via &arg)", &cb )
        retVal = false
      end

      return retVal
    end

    # Gets "all" genboreeuser records for a given Genboree login; obviously
    #   this should be a result set (array of arrays) with exactly 1 row.
    #   Better to just use {#userRecByGbLogin} perhaps, unless you need the
    #   uniformity of always getting back a proper result set.
    # @note You should NOT be calling this directly. Use one of the methods above. Only here for backward compatibility.
    # @param [String] login OPTIONAL. The login, typically the current Redmine login which is default.
    # @return [Array, nil] In non-async / blocking mode, the return is the genboreeuser result set with genboreeuser row matching login or empty if not found.
    #   In async / non-blocking mode, the return should be @true@ and your callback block/Proc will be called with a reesults
    #   Hash (see below).
    # @yieldparam [Hash<Symbol,Object>] results In async / non-blocking mode, your callback is called once the results are ready.
    #   Your code will be called single arg--a hash that has one of 2 keys:
    #   @option results [Array<Array>] :rows The output rows.
    #   @option results [Exception] :err An exception that occurred.
    def userRecsByGbLogin( login, opts={ :caseSensitive => self.class::CASE_SENSITIVE_NAME }, &callback )
      @lastError = nil
      retVal = client = nil
      caseSense = ( opts[:caseSensitive].nil? || self.class::CASE_SENSITIVE_NAME )
      cb = ( block_given? ? saferRackProc( &Proc.new ) : saferRackProc( &callback ) )
      if(cb)
        selectByFieldWithMultipleValues(TABLE, 'name', [login], { :smartBinMode => caseSense }, &cb )
        retVal = true
      else # doing sync w/o callback due to deprecated code
        sql = 'SELECT * FROM genboreeuser WHERE name = '
        begin
          sql << ' BINARY ' if(caseSense)
          sql << " '#{Mysql2::Client.escape(login)}' "
          client = getMysql2Client()
          recs = client.query(sql)
          retVal = recs.entries
        rescue => err
          $stderr.debugPuts(__FILE__, __method__, 'ERROR', "SQL select gave an error. Logging, but returning nil result set.\n  - Error class: #{err.class}\n  - Error message: #{err.message}\n  - Error trace:\n#{err.backtrace.join("\n")}\n\n")
        ensure
          client.close rescue nil
        end
      end
      return retVal
    end

    # ----------------------------------------------------------------
    # HELPERS - meant for internal use but not private in case there is utility for
    #   tightly-coupled classes.
    # ----------------------------------------------------------------

    # Examine this instance and see if appropriate things are filled in for the type of validation.
    # @param [Symbol] type Optional. Defaults to :min4shadowing (the only type supported currently. Type of validation.
    # @return [boolean] Reflecting whether your callback is registered to be called once info has been collects (because
    #   this method calls tableRec(), it may reach out to database, so async).
    # @yieldparam [Hash<Symbol,Object>] results In async / non-blocking mode, your callback is called once the results are ready.
    #   Your code will be called single arg--a hash that has one of 2 keys:
    #   @option results [Array<Array>] :obj This instance
    #   @option results [Exception] :err An exception that occurred, including a RuntimeError when this object fails validation.
    def validateInfo( type=:min4shadowing, opts={}, &callback )
      cb = ( block_given? ? saferRackProc( &Proc.new ) : saferRackProc( &callback ) )

      # No-go decisions
      if(cb)
        userId = self.recId
        login = self.login
        self.tableRec() { |results|
          if( type == :min4shadowing )
            rows = results[:rows] rescue nil
            if( login and !login.to_s.blank? and userId.to_s =~ /^\d+$/ and userId.to_s.to_i >= 0 and rows.is_a?(Array) and !rows.empty? )
              email, firstName, lastName = self.email, self.firstName, self.lastName
              if( !email.to_s.blank? and !firstName.to_s.blank? and !lastName.to_s.blank? )
                cbArg = { :obj => self }
                cb.call( cbArg )
              else
                customErrorViaCallback( RuntimeError, 'This user is not valid and is missing some fields we require. Must have an email address, first name, and last name.')
              end
            else
              customErrorViaCallback( RuntimeError, "Can't get Redmine equivalent of this object since there doesn't appear to be actual Genboree record. Either Genboree user not created yet or information is invalid. This method is only valid for actual Genboree user records. Genboree 'userId' for this object is #{userId.inspect} while the login is #{login.inspect}." )
            end
          else
            customErrorViaCallback( ArgumentError, "Validation type #{type.inspect} is not supported." )
          end
        }
        retVal = true
      else
        customErrorViaCallback( ArgumentError, "ERROR: you must supply a callback method by providing a code block (anonymous block or via &arg)", &cb )
        retVal = false
      end
      return retVal
    end

    # Try to reload the @gbUserRec using the info provided when object was initialized.
    # @return [true] In both blocking and non-blocking mode, this method returns true if the reload attempt completes.
    #   You can interrogate this object--in limited ways if blocking--for data, if any was found.
    # @yieldparam [Hash<Symbol,Object>] results Your callback is called once the results are ready.
    #   Your code will be called with a single arg--a hash that has one of 2 keys:
    #   @option results [Array<Hash>] :rows The output rows.
    #   @option results [Exception] :err An exception that occurred.
    def reload(&callback)
      cb = ( block_given? ? saferRackProc( &Proc.new ) : saferRackProc( &callback ) )
      @gbUserRec = nil
      if(cb) # Then NON-BLOCKING mode
        # Use gbUserRec(), which is non-blocking mode only and does right thing.
        gbUserRec(&callback)
        retVal = true
      else # BLOCKING mode - Exceptions can be raised
        # Similar code as in gbUserRec() but blocking versions.
        if( !@objFor[:login].blank? )
          caseSense = ( ( @objFor.is_a?(Hash) and !@objFor[:caseSensitive].nil? ) ? @objFor[:caseSensitive] : self.class::CASE_SENSITIVE_NAME )
          userRecByGbLogin( @objFor[:login], { :caseSensitive => caseSense } )
        elsif( !@objFor[:email].blank? ) # !@email.blank?
          raise ArgumentError, "ERROR: you cannot instantiate using email without providing a callback."
        else # assume userId
          raise ArgumentError, "ERROR: you cannot instantiate using userId without providing a callback."
        end
        retVal = true
      end

      return retVal
    end

    # Create a user-specific default group for this user.
    def createOwnGroup( &callback )
      cb = ( block_given? ? saferRackProc( &Proc.new ) : saferRackProc( &callback ) )
      grpName = "#{self.login}_group"
      GbDb::GbGroup.create( @rackEnv, grpName, '', 2, { :emCompliant => @emCompliant } ) { |result|
        grp = result[:obj] rescue nil
        if( grp )
          # Add user as admin of their own group
          GbDb::GbUserGroup.create( @rackEnv, grp.recId, self.recId , 'o', 0, { :emCompliant => @emCompliant } ) { |memberResult|
            cb.call( memberResult )
          }
        else
          # Try a different, if uglier, name because {login}_group appears to exist
          @warnings << "WARNING: oddly, a group #{grpName.inspect} already exists even though we just created #{self.login} user."
          grpName = "#{self.login}_#{self.recId}_group"
          GbDb::GbGroup.create( @rackEnv, grpName, '', 2, { :emCompliant => @emCompliant } ) { |result2|
            grp = result2[:obj] rescue nil
            if( grp )
              # Add user as admin of their own group
              GbDb::GbUserGroup.create( @rackEnv, grp.recId, self.recId , 'o', 0, { :emCompliant => @emCompliant } ) { |memberResult|
                cb.call( memberResult )
              }
            end
          }
        end
      }
    end

    private

    # Private constructor. Instantiate via EITHER login, email, or userId. If using email, the OLDEST
    #   genboree account with that login will be used.
    # @note Meant to be called by the public factory constructor methods.
    # @param [Hash] rackEnv The Rack env hash.
    # @param [Hash{Symbol,Object}] opts A Hash with one and only one of 3 keys providing the info to be used to instantiate
    #   the object, and optionally a :dbHost key if you know the MySQL instance host to connect to (else GbApi::GbAuthHelper
    #   will be created and asked for the appropriate host info).
    #   @options opts [String] :login The genboree login ('name' column value)
    #   @options opts [String] :email The genboree account email (oldest account with that email will be used)
    #   @options opts [Fixnum] :userId The genboree account userID (row id)
    #   @options opts [String] :dbHost The MySQL instance host to connect to, if known. If not {GbApi::GbAuthHelper}
    #     will be instantiated to answer this.
    # @raise ArgumentError If you provide values for more than one of, or none of, :login, :email, :userID
    # @todo Remove the fallback to User.current as it is not async-safe.
    def initialize( rackEnv, opts = { :login => (rackEnv[:currRmUser] ? rackEnv[:currRmUser].login : User.current.login), :dbHost => host } )
      # Options
      methodInfo = METHOD_INFO[__method__]
      opts = methodInfo[:opts].merge(opts)

      @objFor = { :login => opts[:login], :email => opts[:email], :userId => opts[:userId], :caseSensitive => opts[:caseSensitive] }
      unless( [:login, :email, :userId].one?{|kk| !@objFor[kk].to_s.blank?} )
        raise ArgumentError, "ERROR: Must provide one (and only one) of :login or :email keys; whichever is provided will be used to find the user record (if any exists). Maybe you should use the simpler factory methods GbUser.byName(), GbUser.byEmail(), or GbUser.byId(). If you think you provided one--maybe via assumed rackEnv[:currRmUser]--it's actually nil. @objFor was: #{@objFor.inspect}"
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

    # Get the value of some field in a loaded @gbUserRec (i.e. must exist and have been loaded)
    # @param [String] field The field or column name to get the value for.
    # @return [Object, nil] The value of the field or nil if missing or there is no gbUserRec.
    def fieldValue(field)
      return ( @gbUserRec.is_a?(Hash) ? @gbUserRec[field] : nil)
    end

    # Update the state of this object from a result set--generally from a lookup query. If results empty or
    #   or invalid (no record found or perhaps error) then update state appropriately.
    # @note Upon updating from actual row/record, the @@objFor@ instance variable will change to contain the *userId*
    #   for the record. Thus @@objFor@ content may be different than right after initialization, where it contained
    #   login [possibly non-existent] or email [possibly non-existent or now changed!] info provided. Having this updated
    #   correctly is a key reason for this method.
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
          @gbUserRec = rec
          caseSense = ( (@objFor.is_a?(Hash) and !@objFor[:caseSensitive].nil?) ? @objFor[:caseSensitive] : self.class::CASE_SENSITIVE_NAME )
          # Switch from however initialized to userId based reloading (in case of update or other changes)
          @objFor = { :userId => fieldValue('userId'), :login => nil, :email => nil, :caseSensitive => caseSense }
        else # no rec found
          # Leave objFor unchanged, since no better info available
          @gbUserRec = nil
        end
        retVal = @gbUserRec
      end
      return retVal
    end
  end
end
