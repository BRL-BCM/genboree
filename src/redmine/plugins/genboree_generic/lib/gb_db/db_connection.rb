require 'mysql2'
require 'mysql2/em'
require 'brl/db/dbrc'
require 'gb_ext/string/gsubSqlSafe'

module GbDb

  # Generic DbConnection class. Intended for use with genboree ecosystem databases and tailored querying--especially
  #   via sub-classes--but is generic to be used with any MySQL database instance.
  class DbConnection
    include GbMixin::AsyncRenderHelper

    METHOD_INFO = {
      :initialize => {
        :opts => { :dbrcType => :db, :emCompliant => true, :dbName => nil }
      }
    }
    MAX_RETRIES = 5

    attr_reader :lastError
    attr_reader :dbrc, :dbrcRec, :host, :port, :socket
    attr_accessor :dbrc
    attr_accessor :emCompliant

    # Initialize for a given MySQL instance host.
    # @param [Hash] rackEnv The Rack env hash.
    # @param [String] host The MySQL host.
    # @param [Hash] opts Optional. Additional options affecting initialization.
    # @option opts [Symbol] :dbrcType The kind of DBRC record to use to find connection info
    #   to the database running on @host@. Typically is either :db or :toku.
    def initialize(rackEnv, host, opts=METHOD_INFO[__method__][:opts])
      # Options
      methodInfo = METHOD_INFO[__method__]
      #$stderr.debugPuts(__FILE__, __method__, 'DEBUG', "incoming opts: #{opts.inspect}")

      opts = methodInfo[:opts].merge(opts)
      dbrcType = opts[:dbrcType]
      dbName = opts[:dbName]
      #$stderr.debugPuts(__FILE__, __method__, 'DEBUG', "merged opts: #{opts.inspect}")
      #$stderr.debugPuts(__FILE__, __method__, 'DEBUG', "Given DATABASE NAME: #{dbName.inspect}")
      # Save key Rack callbacks, info, etc
      initRackEnv( rackEnv )
      # Set up database auth info
      @dbrc = BRL::DB::DBRC.new()
      # We may have been given a KNOWN database name. If so, we'll retrieve & activate record a little differently.
      if( dbName )
        # User {type}:{host} record from .dbrc, but replace database with the KNOWN one that was supplied
        @dbrcRec = @dbrc.getRecordByHostForDb( host, dbrcType, dbName )
      else
        # Use database mentioned in the .dbrc record.
        @dbrcRec = @dbrc.getRecordByHost( host, opts[:dbrcType] )
      end

      @emCompliant = ( ( opts[:emCompliant].nil? or opts[:emCompliant] ) ? true : false )
      raise "FATAL ERROR: No '#{opts[:dbrcType].to_s.upcase}:' type access record for host #{host.inspect}." unless(@dbrcRec)
      @dbrc.makeActive( @dbrcRec )
      #$stderr.debugPuts(__FILE__, __method__, 'DEBUG', "Active DATABASE NAME: (#{@dbrc.object_id.inspect}) #{@dbrc.dbName.inspect}")
    end

    # Get a Mysql2 client connected to the authenticating Genboree's main MySQL database.
    # @note Will apply retrying if immediate connection unsuccessful.
    # @note By default this is a BLOCKING client, for backward compatibility. If you want to work in
    #   non-blocking mode (recommended!) you must provide the @:emCompliant=>false@ option.
    # @return [Mysql2::Client, Mysql2::EM::Client, nil] In blocking mode you get a connected {Mysql2::Client},
    #   in non-blocking mode you get a connected {Mysql2::EM::Client}, else if error you get nil.
    def getMysql2Client( opts = { :emCompliant => @emCompliant } )
      client = nil

      # @todo if going to retry MUST be done non-blocking via EM and NO SLEEP (blocks)
      maxRetries = ( @dbrc.max_reconn or MAX_RETRIES )
      emCompliant = ( opts[:emCompliant] ? true : false )

      # Try to create client which will establish connection to mysql server
      lastConnErr = nil # The last Exception thrown during the creation attempt.
      connRetries = 0

      # @todo if going to retry MUST be done non-blocking via EM and NO SLEEP (blocks)
      #loop {
        if(connRetries < maxRetries)
          connRetries += 1
          begin
            # Build client config
            #$stderr.debugPuts(__FILE__, __method__, 'DEBUG', "Get client for active DATABASE NAME: (#{@dbrc.object_id.inspect}) #{@dbrc.dbName.inspect}")
            config = { :username => @dbrc.user, :password => @dbrc.password, :database => @dbrc.dbName }
            if(@dbrc.host)
              config[:host] = @dbrc.host
              config[:port] = @dbrc.port if(@dbrc.port)
            else # unix socket
              config[:socket] = @dbrc.socket
            end
            # Make client
            if(emCompliant)
              client = Mysql2::EM::Client.new(config)
            else # non-EM
              client = Mysql2::Client.new(config)
            end
            #$stderr.debugPuts(__FILE__, __method__, 'DEBUG', "emCompliant: #{@emCompliant.inspect} ; mysql client type: #{client.class}")
          rescue Exception => lastConnErr
            # Slightly variable progressive sleep.
            sleepTime = ((connRetries / 2.0) + 0.4 + rand())
            # 1-line log msg about this failure
            $stderr.debugPuts(__FILE__, __method__, 'WARNING', "Attempt ##{connRetries} DB connect to #{@host ? @host.inspect : @socket.inspect} failed. Will retry in #{'%.2f' % sleepTime} secs. Maximum total attempts: #{maxRetries}. Exception class and message: #{lastConnErr.class} (#{lastConnErr.message.inspect}). Currently WILL NOT retry connection, because will block unless done properly via async EM.")
            # @todo if going to retry MUST be done non-blocking via EM and NO SLEEP (blocks)
            # sleep(sleepTime)
          end
        else  # Tried many times and still cannot connect. Big problem...
          msg = "ALL #{connRetries} attempts failed to establish DB connection to #{@host ? @host.inspect : @socket.inspect}. Was using these params: maxRetries = #{maxRetries.inspect}, host = #{@host.inspect}, socket = #{@socket.inspect}, username = #{@dbrc.user.inspect}, database = #{@dbrc.dbName.inspect}, driver = #{@dbrc.driver.inspect}.\n\n"
          $stderr.debugPuts(__FILE__, __method__, 'FATAL', "\n\n#{msg}\n\n")
          raise Exception, msg
        end

      # @todo if going to retry MUST be done non-blocking via EM and NO SLEEP (blocks)
      # break if(client)
      #}
      #$stderr.debugPuts(__FILE__, __method__, 'DEBG', "mysql client class: #{client.class}")
      return client
    end

    # ----------------------------------------------------------------
    # GENERICS
    # - Add more from brl/genboree/dbUtil.rb as needed. Convert carefully using already ported ones.
    # - Can added more features to opts hash for existing method, such as group-by, sort-by, etc support. Even binary matching maybe.
    #   . If you do, add for ALL not just your tunnel-vision one.
    # ----------------------------------------------------------------

    SQL_PATTERN_selectByFieldAndValues = 'SELECT {distinct} {desiredFields} FROM {tableName} WHERE {fieldName} IN '
    # Generic select records using 1+ values for a specific field.
    #   Can get distinct or non-distict rows.
    #   Can specify specific columns in result set.
    # @note ONLY for use within a running EM loop! Ok, it will work outside as long as you give it callback, but it will
    #   yell at you on stderr for not doing things the proper way.
    # @param [String] tableName Name of the table to select from.
    # @param [String] fieldName Name of field which to select on
    # @param [Array<String>] fieldValues Array of values which @fieldName@ can be.
    # @param [Hash{Symbol,Object}] opts Hash of additional options for the query. Common keys are:
    #   @option opts [Array<String>] :desiredFields Array of desired output fields. If missing, then all.
    #   @option opts [Boolean] :distinct True if output rows should be distinct.
    #   @option opts [Hash{String,Symbol}] :orderBy Hash of utput fields mapped to direction Symbols (@:asc@ or @:desc@) for order by.
    #     Field(s) MUST be in :desiredFields if that option is provided. Order by can be EXPENSIVE unless you have studied/considered
    #     the table indexes in the context of your output fields + order by fields.
    #   @option opts [Boolean] :smartBinMode False by default, if true this will employ a 'smart binary matching' mode in order to
    #     to do CASE-SENSITIVE MATCHING on columns that are not defined as BINARY or with a _bin COLLATION. Many google'd solutions
    #     and MySQL docs indicate that you should use the COLLATE operator so that MySQL treats either operand (generally a column and a
    #     test value, or two columns) using COLLATE casting. This can mean indexes--which are based on the real, underlying collations--
    #     are not used and minimally entails a lot of collation operations of table values during search. Also if you do this, the index
    #     (even if it was selected for use) CANNOT be used to aid ORDER BY which is now slower. Using the binary collations via the
    #     BINARY operator has similar problems and certainly won't use your non-binary-based indexes! An elegant solution to this
    #     ensures that the correct index is used for identifying matching rows AND that index can be used to aid ORDER BY. This
    #     "smart binary mode" does BOTH the "{column} = {value}" matching using default collation AND the "{column} = BINARY {value}"
    #     case-sensitive condition. The first employs the default collation and indexes--which can be employed during ORDER BY if relevant--
    #     case-sensitive condition. The first employs the default collation and indexes--which can be employed during ORDER BY if relevant--
    #     during SQL compilation & query-planning/execution to efficiently find matching rows, but then further filters the matching rows by
    #     requiring a BINARY match of the column value vs the query value. If you think the answer is simply to employ BINARY string types or
    #     binary collations, you should think about what that means for sensible ORDER BY; i.e. sensible sort is "alphabetic" (non-binary,
    #     non-binary collation) where "geek/stupid" sort is ASCII sort order. You end up having to resort sensibly in code or sort inefficiently
    #     in SQL...when you could be doing something smarter...like :smartBinMode=true
    # @return [Boolean] Generally returns true and your callback is registered with EM loop and will be called when query completes.
    #   However if some error happens during preparation, then your callback will be called with error info on the next tick and
    #   this method returns @false@. If you're not using EM [not how intended] then in the case of prep error your callback is
    #   called immediately from within this method and THEN this method returns @false@; i.e. the intended ordering is not present.
    # @yieldparam [Hash<Symbol,Object>] results The code block/Proc callback will be called with a single arg--a hash that
    #   has one of 2 keys:
    #   @option results [Array<Array>] :rows The output rows.
    #   @option results [Exception] :err An exception that occurred.
    def selectByFieldWithMultipleValues( tableName, fieldName, fieldValues, opts = { :desiredFields => nil, :distinct => false, :orderBy => nil, :smartBinMode => false }, &callback )
      retVal = true
      client = deferredRS = nil
      smartBinMode = opts[:smartBinMode]
      cb = ( block_given? ? saferRackProc( &Proc.new ) : saferRackProc( &callback ) )

      # No-go decisions
      if( cb )
        # First, set up the async sql query
        begin
          # Build desired fields SQL partial
          desiredFieldsStr = desiredFieldsSqlPartial( opts )
          # Build distinct SQL partial
          distinctStr = distinctSqlPartial( opts )
          # Build order-by SQL partial
          orderByStr = orderBySqlPartial( opts )
          # Build final SQL
          sql = SQL_PATTERN_selectByFieldAndValues.gsub(/\{tableName\}/, tableName).gsub(/\{fieldName\}/, fieldName)
          sql = sql.gsub('{distinct}', distinctStr).gsub('{desiredFields}', desiredFieldsStr)
          # First, add the IN set that will use the index--via its default collation and the values as-is (case insensitve, but employs index)
          # - By ensuring that index is employ in "default" way, even for case-sensitive matching, we avoid losing this index
          #   during any ORDER BY phase.
          #   . This can be seen via EXPLAIN. Case-sensitive searches (via BINARY operator) will employ the index to find matches,
          #     but will not use the index for ORDER BY; it ends up doing "Using where; Using filesort" rather than just "Using where"
          sql << self.class.makeMysqlSetStr(fieldValues, { :smartBinMode => false } )
          # Next, IF doing case-sensitive via BINARY operator (binary collation), also add in the case-sensitive version which acts as
          # a post-matching filter.
          if( smartBinMode )
            where2 = ' AND {fieldName} IN '.gsub(/\{fieldName\}/, fieldName)
            where2 << self.class.makeMysqlSetStr(fieldValues, { :smartBinMode => true } )
            sql << where2
          end
          # Add the ORDER BY if any
          sql << " #{orderByStr}"
          # Create EM-compliant mysql2 client
          client = getMysql2Client( opts.merge( { :emCompliant => @emCompliant } ) )
          # Arrange for EM to run query next available EM iteration
          deferredRS = client.query(sql)
        rescue => err
          client.close rescue nil
          retVal = false
          $stderr.debugPuts(__FILE__, __method__, 'FATAL ERROR', "Failed to set up select-by-field-and-values type asynchronous SQL query.\n    Error Class: #{err.class}\n    Error Msg: #{err.message}\n    sql: #{sql.to_s[0,1024]}\n    Error Trace:\n#{err.backtrace.join("\n")}\n\n")
          # Try to call their callback with error info
          if(EM and EM.reactor_running?)
            EM.next_tick {
              cb.call( { :err => err } )
            }
          else # call right away, sync & from within this method (not preferred and is weird; good for testing.)
            cb.call( { :err => err } )
          end
          return retVal
        end

        # We do this here so as not to have it wrapped by the begin-rescue (relevant in BLOCKING mode, we don't want to wrap user's code)
        # - But only call if not rescued above; else callbacks can be called twice in BLOCKING mode.
        resultSetViaCallback( deferredRS, client, sql, &cb ) if( retVal )
      else
        customErrorViaCallback( ArgumentError, "ERROR: you must supply a callback method by providing a code block (anonymous block or via &arg)", &cb )
        retVal = false
      end

      return retVal
    end

    SQL_PATTERN_selectByFieldValueMap = 'SELECT {distinct} {desiredFields} FROM {tableName} WHERE '
    # Generic select records whose select field=value conditions are provided via a map.
    #   Can combine all field=value conditions via 'AND' or via 'OR'.
    #   Can get distinct or non-distict rows.
    #   Can specify specific columns in result set.
    #
    #   For example:    @fieldValueMap = {'col1'=>'x', 'col2'=>'y'} ;  booleanOp = :and@
    #   Would create:   'select * from tableName where col1 = 'x' and col2 = 'y' ;
    #
    # @note ONLY for use within a running EM loop! Ok, it will work outside as long as you give it callback, but it will
    #   yell at you on stderr for not doing things the proper way.
    # @param [String] tableName Name of the table to select from.
    # @param [Hash{String,String}] col2val Hash containing the field=value conditions that will be used in SQL WHERE clause.
    #   Must have the format: { 'fieldName1' => 'valueA', 'fieldName2' => 'valueB' }
    # @param [Symbol] op Symbol indicating the boolean operator used to combine multiple field=value conditions;
    #   one of @:and@ or @:or@ .
    # @param [Hash{Symbol,Object}] opts Hash of additional options for the query. Common keys are:
    #   @option opts [Array<String>] :desiredFields Array of desired output fields. If missing, then all.
    #   @option opts [Boolean] :distinct True if output rows should be distinct.
    #   @option opts [Boolean] :smartBinMode False by default, if true this will employ a 'smart binary matching' mode in order to
    #     to do CASE-SENSITIVE MATCHING on columns that are not defined as BINARY or with a _bin COLLATION. Many google'd solutions
    #     and MySQL docs indicate that you should use the COLLATE operator so that MySQL treats either operand (generally a column and a
    #     test value, or two columns) using COLLATE casting. This can mean indexes--which are based on the real, underlying collations--
    #     are not used and minimally entails a lot of collation operations of table values during search. Also if you do this, the index
    #     (even if it was selected for use) CANNOT be used to aid ORDER BY which is now slower. Using the binary collations via the
    #     BINARY operator has similar problems and certainly won't use your non-binary-based indexes! An elegant solution to this
    #     ensures that the correct index is used for identifying matching rows AND that index can be used to aid ORDER BY. This
    #     "smart binary mode" does BOTH the "{column} = {value}" matching using default collation AND the "{column} = BINARY {value}"
    #     case-sensitive condition. The first employs the default collation and indexes--which can be employed during ORDER BY if relevant--
    #     during SQL compilation & query-planning/execution to efficiently find matching rows, but then further filters the matching rows by
    #     requiring a BINARY match of the column value vs the query value. If you think the answer is simply to employ BINARY string types or
    #     binary collations, you should think about what that means for sensible ORDER BY; i.e. sensible sort is "alphabetic" (non-binary,
    #     non-binary collation) where "geek/stupid" sort is ASCII sort order. You end up having to resort sensibly in code or sort inefficiently
    #     in SQL...when you could be doing something smarter...like :smartBinMode=true
    # @return [Boolean] Generally returns true and your callback is registered with EM loop and will be called when query completes.
    #   However if some error happens during preparation, then your callback will be called with error info on the next tick and
    #   this method returns @false@. If you're not using EM [not how intended] then in the case of prep error your callback is
    #   called immediately from within this method and THEN this method returns @false@; i.e. the intended ordering is not present.
    # @yieldparam [Hash<Symbol,Object>] results The code block/Proc callback will be called with a single arg--a hash that
    #   has one of 2 keys:
    #   @option results [Array<Array>] :rows The output rows.
    #   @option results [Exception] :err An exception that occurred.
    def selectByFieldValueMap(tableName, col2val, op, opts = { :desiredFields => nil, :distinct => false, :smartBinMode => false }, &callback)
      retVal = true
      client = deferredRS = nil
      smartBinMode = opts[:smartBinMode]
      cb = ( block_given? ? saferRackProc( &Proc.new ) : saferRackProc( &callback ) )

      # No-go decisions
      if( cb )
        # First, set up the async sql query
        begin
          # Build desired fields SQL partial
          desiredFieldsStr = desiredFieldsSqlPartial( opts )
          # Build distinct SQL partial
          distinctStr = distinctSqlPartial( opts )
          # Build order-by SQL partial
          orderByStr = orderBySqlPartial( opts )
          sql = SQL_PATTERN_selectByFieldValueMap.gsub(/\{tableName\}/, tableName)
          sql = sql.gsub('{distinct}', distinctStr).gsub('{desiredFields}', desiredFieldsStr)
          # First, add the field=value conditions that will use the index--via its default collation and the values as-is
          #   (case insensitve, but employs index)
          # - By ensuring that index is employ in "default" way, even for case-sensitive matching, we avoid losing this index
          #   during any ORDER BY phase.
          #   . This can be seen via EXPLAIN. Case-sensitive searches (via BINARY operator) will employ the index to find matches,
          #     but will not use the index for ORDER BY; it ends up doing "Using where; Using filesort" rather than just "Using where"
          sql << ' ( '
          sql << self.class.makeMysqlKeyValuePairsSql(col2val, nil, op, { :smartBinMode => false } )
          sql << ' ) '
          # Next, IF doing case-sensitive via BINARY operator (binary collation), also add in the case-sensitive version which acts as
          # a post-matching filter.
          if( smartBinMode )
            sql << ' AND ( '
            sql << self.class.makeMysqlKeyValuePairsSql(col2val, nil, op, { :smartBinMode => true } )
            sql << ' ) '
          end
          # Add in ORDER BY, if any
          sql << " #{orderByStr}"
          # Create EM-compliant mysql2 client
          client = getMysql2Client( opts.merge( { :emCompliant => @emCompliant } ) )
          # Arrange for EM to run query next available EM iteration
          deferredRS = client.query(sql)
        rescue => err
          client.close rescue nil
          retVal = false
          $stderr.debugPuts(__FILE__, __method__, 'FATAL ERROR', "Failed to set up select-by-field2value-map type asynchronous SQL query.\n    Error Class: #{err.class}\n    Error Msg: #{err.message}\n    sql: #{sql.to_s[0,1024]}\n    Error Trace:\n#{err.backtrace.join("\n")}\n\n")
          # Try to call their callback with error info
          if(EM and EM.reactor_running?)
            EM.next_tick {
              cb.call( { :err => err } )
            }
          else # call right away, sync & from within this method (not preferred and is weird; good for testing.)
            cb.call( { :err => err } )
          end
        end

        # We do this here so as not to have it wrapped by the begin-rescue (relevant in BLOCKING mode, we don't want to wrap user's code)
        # - But only call if not rescued above; else callbacks can be called twice in BLOCKING mode.
        resultSetViaCallback( deferredRS, client, sql, &cb ) if( retVal )
      else
        customErrorViaCallback( ArgumentError, "ERROR: you must supply a callback method by providing a code block (anonymous block or via &arg)", &cb )
        retVal = false
      end

      return retVal
    end

    SQL_PATTERN_updateColumnsByFieldValueMap = 'UPDATE {tableName} SET {setStr} WHERE {whereStr}'
    # Generic method to set 1+ column=value all records which match 1+ field=value conditions. You
    #   can determine if the field=value conditions are joined by 'AND' or by 'OR' when selecting rows
    #   to update...but in all matched rows your various column=value will be set.
    # @note if multiple things match your field name & value pair, then you will update ALL of them.
    #   Make sure you know in your code whether multiple matches are possible and process all results
    #   accordingly. Just because you think application logic means only be one SHOULD be returned is
    #   not enough; if table allows more than one item to have tha field name & value, you should check
    #   that you recieved what your application logic expect. If you didn't error, warn, or deal appropriately.
    #
    # @param [String] tableName   Name of the table to select from.
    # @param [Hash{String,String}] setCol2Val Hash of column names to values which will be SET for matching records.
    # @param [Hash{String,String}] matchCol2Val Hash of field names to values which are used for WHERE conditions.
    # @param [Symbol] op Either of @:and@ or @:or@, depending on whether ALL or ANY of your field=value conditions must be matched
    #   Typically to provide context info of the call (eg name of method calling this one, etc)
    # @param [Hash{Symbol,Object}] opts Hash of additional options for the query.
    #   @option opts [Boolean] :smartBinMode False by default, if true this will employ a 'smart binary matching' mode in order to
    #     to do CASE-SENSITIVE MATCHING on columns that are not defined as BINARY or with a _bin COLLATION. Many google'd solutions
    #     and MySQL docs indicate that you should use the COLLATE operator so that MySQL treats either operand (generally a column and a
    #     test value, or two columns) using COLLATE casting. This can mean indexes--which are based on the real, underlying collations--
    #     are not used and minimally entails a lot of collation operations of table values during search. Also if you do this, the index
    #     (even if it was selected for use) CANNOT be used to aid ORDER BY which is now slower. Using the binary collations via the
    #     BINARY operator has similar problems and certainly won't use your non-binary-based indexes! An elegant solution to this
    #     ensures that the correct index is used for identifying matching rows AND that index can be used to aid ORDER BY. This
    #     "smart binary mode" does BOTH the "{column} = {value}" matching using default collation AND the "{column} = BINARY {value}"
    #     case-sensitive condition. The first employs the default collation and indexes--which can be employed during ORDER BY if relevant--
    #     during SQL compilation & query-planning/execution to efficiently find matching rows, but then further filters the matching rows by
    #     requiring a BINARY match of the column value vs the query value. If you think the answer is simply to employ BINARY string types or
    #     binary collations, you should think about what that means for sensible ORDER BY; i.e. sensible sort is "alphabetic" (non-binary,
    #     non-binary collation) where "geek/stupid" sort is ASCII sort order. You end up having to resort sensibly in code or sort inefficiently
    #     in SQL...when you could be doing something smarter...like :smartBinMode=true
    # @return [Boolean] Generally returns true and your callback is registered with EM loop and will be called when query completes.
    #   However if some error happens during preparation, then your callback will be called with error info on the next tick and
    #   this method returns @false@. If you're not using EM [not how intended] then in the case of prep error your callback is
    #   called immediately from within this method and THEN this method returns @false@; i.e. the intended ordering is not present.
    # @yieldparam [Hash<Symbol,Object>] results The code block/Proc callback will be called with a single arg--a hash that
    #   has one of 2 keys:
    #   @option results [Array<Array>] :count The number of updated rows.
    #   @option results [Exception] :err An exception that occurred.
    def updateColumnsByFieldAndValue(tableName, setCol2Val, matchCol2Val, op, opts={ :smartBinMode => false }, &callback)
      retVal = true
      client = deferredRS = nil
      smartBinMode = opts[:smartBinMode]
      cb = ( block_given? ? saferRackProc( &Proc.new ) : saferRackProc( &callback ) )

      # No-go decisions
      if( cb )
        # First, set up the async sql query
        begin
          # Build SQL
          sql = SQL_PATTERN_updateColumnsByFieldValueMap.gsub(/\{tableName\}/, tableName)
          # Create and add column SET sql partial
          cols, vals = [], []
          setStr = self.class.makeMysqlKeyValuePairsSql(setCol2Val, nil, :comma)
          # CANNOT use regular gsub when placing properly ESCAPED values (e.g. strings from user) into the template SQL
          # * Because the SQL escape sequence \' looks like the backreference version of $' ($POSTMATCH) and since gsub is ALWAYS
          #   regexp-based internally, it will corrupt your replacement with stuff from the matcher. We have a monkey-patch solution.
          sql = sql.gsubSqlSafe(/\{setStr\}/, setStr)
          # Add in column WHERE conditions
          # First, add the field=value conditions that will use the index--via its default collation and the values as-is
          #   (case insensitve, but employs index)
          # - By ensuring that index is employ in "default" way, even for case-sensitive matching, we avoid losing this index
          #   during any ORDER BY phase.
          #   . This can be seen via EXPLAIN. Case-sensitive searches (via BINARY operator) will employ the index to find matches,
          #     but will not use the index for ORDER BY; it ends up doing "Using where; Using filesort" rather than just "Using where"
          whereStr = ' ( '
          whereStr << self.class.makeMysqlKeyValuePairsSql(matchCol2Val, nil, op, { :smartBinMode => false } )
          whereStr << ' ) '
          # Next, IF doing case-sensitive via BINARY operator (binary collation), also add in the case-sensitive version which acts as
          # a post-matching filter.
          if( smartBinMode )
            whereStr << ' AND ( '
            whereStr << self.class.makeMysqlKeyValuePairsSql(matchCol2Val, nil, op, { :smartBinMode => true } )
            whereStr << ' ) '
          end

          # CANNOT use regular gsub when placing properly ESCAPED values (e.g. strings from user) into the template SQL
          # * Because the SQL escape sequence \' looks like the backreference version of $' ($POSTMATCH) and since gsub is ALWAYS
          #   regexp-based internally, it will corrupt your replacement with stuff from the matcher. We have a monkey-patch solution.
          sql = sql.gsubSqlSafe(/\{whereStr\}/, whereStr)
          # Create EM-compliant mysql2 client
          client = getMysql2Client( opts.merge( { :emCompliant => @emCompliant } ) )
          # Arrange for EM to run query next available EM iteration
          deferredRS = client.query(sql)
        rescue => err
          client.close rescue nil
          retVal = false
          $stderr.debugPuts(__FILE__, __method__, 'FATAL ERROR', "Failed to set up update-cols-for-fields=values type asynchronous SQL query.\n    Error Class: #{err.class}\n    Error Msg: #{err.message}\n    sql: #{sql.to_s[0,1024]}\n    Error Trace:\n#{err.backtrace.join("\n")}\n\n")
          # Try to call their callback with error info
          if(EM and EM.reactor_running?)
            EM.next_tick {
              cb.call( { :err => err } )
            }
          else # call right away, sync & from within this method (not preferred and is weird; good for testing.)
            cb.call( { :err => err } )
          end
        end

        # We do this here so as not to have it wrapped by the begin-rescue (relevant in BLOCKING mode, we don't want to wrap user's code)
        # - But only call if not rescued above; else callbacks can be called twice in BLOCKING mode.
        affectedCountViaCallback( deferredRS, client, sql, &cb ) if( retVal )
      else
        customErrorViaCallback( ArgumentError, "ERROR: you must supply a callback method by providing a code block (anonymous block or via &arg)", &cb )
        retVal = false
      end

      return retVal
    end

    SQL_PATTERN_upsertByFieldValueMap = 'INSERT INTO {tableName}({colList}) VALUES {valList} ON DUPLICATE KEY UPDATE {onDupUpdateList} '
    # Generic method to upsert (insert new or update if already exists) a table record by supplying most values. By providing most
    #   values, when the insert runs it will try to insert a new record but if there is an existing row with the identifying column value,
    #   then that record is updated with the non-identifying column values. Thus it can work for both creating NEW records and UPDATING
    #   existing ones.
    # @note This method should be used VERY CAREFULLY since it can easily (a) mess up existing records and change things
    #   that should not be changeable after first insertion [e.g. if the column list mentions MORE THAN ONE uniquely
    #   indexed column, such as row id AND unique name, then you are probably using it wrong and should not have provided
    #   the row id] ; (b) add a new record when you really intended on updating an exsiting one.
    # @note i.e. carelessness or abuse can end up CORRUPTING THE WHOLE TABLE.
    # @param [String] tableName  Name of the table to select from.
    # @param [Hash{String,String}] col2val Hash of column names to values for the upserted record.
    # @param [Array<String>] identCols ORDERED array of column(s) that is the identifying column(s) for this upsert; taking ALL together,
    #   they must form a unique, row-identifying index. Generally just 1 column, such as the row id or some single unique column like a
    #   unique name (in which case, don't provide row id anywhere). But unique multi-columns are also supported if you list them here.
    #   Typically to provide context info of the call (eg name of method calling this one, etc)
    # @param [Hash{Symbol,Object}] opts Hash of additional options for the query.
    # @return [Boolean] Generally returns true and your callback is registered with EM loop and will be called when query completes.
    #   However if some error happens during preparation, then your callback will be called with error info on the next tick and
    #   this method returns @false@. If you're not using EM [not how intended] then in the case of prep error your callback is
    #   called immediately from within this method and THEN this method returns @false@; i.e. the intended ordering is not present.
    # @yieldparam [Hash<Symbol,Object>] results The code block/Proc callback will be called with a single arg--a hash that
    #   has one of 2 keys:
    #   @option results [Array<Array>] :count The number of updated rows.
    #   @option results [Exception] :err An exception that occurred. Will be an ArgumentError  you don't supply acceptable column names,
    #     or the column(s) in identCols are not keys in col2val.
    def upsertByFieldValueMap(tableName, col2val, identCols, opts={}, &callback)
      retVal = true
      client = deferredRS = nil
      cb = ( block_given? ? saferRackProc( &Proc.new ) : saferRackProc( &callback ) )
      cols = col2val.keys.sort{ |aa,bb| rv = (aa.downcase <=> bb.downcase) ; rv = (aa <=> bb) if(rv == 0) ; rv  }
      identCols = identCols.sort{ |aa,bb| rv = (aa.downcase <=> bb.downcase) ; rv = (aa <=> bb) if(rv == 0) ; rv  }

      # No-go decisions
      if( cb )
        if( identCols.all?{|xx| cols.include?(xx)} )
          # First, set up the async sql query
          begin
            # Build SQL
            sql = SQL_PATTERN_upsertByFieldValueMap.gsub(/\{tableName\}/, tableName)
            # Add column list after the table name. i.e. what values we are changing and in what order.
            colListStr = self.class.makeMysqlColumnListSql( cols )
            sql = sql.gsub( /\{colList\}/, colListStr )
            # Add value list (SAME order, must be guarranteed same)
            vals = [] ; cols.each { |xx| vals << col2val[xx].to_s.strip }
            valListStr = self.class.makeMysqlSetStr( vals )
            # CANNOT use regular gsub when placing properly ESCAPED values (e.g. strings from user) into the template SQL
            # * Because the SQL escape sequence \' looks like the backreference version of $' ($POSTMATCH) and since gsub is ALWAYS
            #   regexp-based internally, it will corrupt your replacement with stuff from the matcher. We have a monkey-patch solution.
            sql = sql.gsubSqlSafe( /\{valList\}/, valListStr )
            # Add on duplicate update sql (only need the column names for this)
            updateCols = ( cols - identCols )
            onDupUpdateStr = self.class.makeMysqlOnDupUpdateSql( updateCols )
            # CANNOT use regular gsub when placing properly ESCAPED values (e.g. strings from user) into the template SQL
            # * Because the SQL escape sequence \' looks like the backreference version of $' ($POSTMATCH) and since gsub is ALWAYS
            #   regexp-based internally, it will corrupt your replacement with stuff from the matcher. We have a monkey-patch solution.
            sql = sql.gsubSqlSafe( /\{onDupUpdateList\}/, onDupUpdateStr )
            #$stderr.debugPuts(__FILE__, __method__, 'DEBUG', "SQL:  #{sql} ")
            # Create EM-compliant mysql2 client
            client = getMysql2Client( opts.merge( { :emCompliant => @emCompliant } ) )
            # Arrange for EM to run query next available EM iteration
            deferredRS = client.query(sql)
          rescue => err
            client.close rescue nil
            retVal = false
            $stderr.debugPuts(__FILE__, __method__, 'FATAL ERROR', "Failed to set up upsert-by-field2value-map type asynchronous SQL query.\n    Error Class: #{err.class}\n    Error Msg: #{err.message}\n    sql: #{sql.to_s[0,1024]}\n    Error Trace:\n#{err.backtrace.join("\n")}\n\n")
            # Try to call their callback with error info
            if(EM and EM.reactor_running?)
              EM.next_tick {
                cb.call( { :err => err } )
              }
            else # call right away, sync & from within this method (not preferred and is weird; good for testing.)
              cb.call( { :err => err } )
            end
          end

          # We do this here so as not to have it wrapped by the begin-rescue (relevant in BLOCKING mode, we don't want to wrap user's code)
          # - But only call if not rescued above; else callbacks can be called twice in BLOCKING mode.
          #$stderr.debugPuts(__FILE__, __method__, 'DEBUG', "deferredRS:\n\n#{JSON.pretty_generate(deferredRS)}\n\n")
          affectedCountViaCallback( deferredRS, client, sql, &cb ) if( retVal )
        else
          customErrorViaCallback( ArgumentError, "ERROR: there are columns in identCols which are not in the column=value map. That's wrong.", &cb )
          retVal = false
        end
      else
        customErrorViaCallback( ArgumentError, "ERROR: you must supply a callback method by providing a code block (anonymous block or via &arg)", &cb )
        retVal = false
      end

      return retVal
    end

    # This "generic" method just executes the SQL provided. No building correct SQL or anything.
    #   Should be AVOIDED for any core Genboree or Redmine tables IN MOST cases. It is present
    #   to support other specific-purpose libs that have app-specific tables and know how to construct
    #   the very app-specific SQL to query their tables sensibly.
    # @param [String] sql The raw SQL to execute.
    # @param [Hash] opts Optional. Hash with options.
    # @option opts [Symbol] :want Either a Symbol :rows [default], :affectedCount to indicate the SQL scenario.
    #   Indicate what you are expecting from your custom SQL. This will be used to determine the correct argument to your
    #   callback. If you're doing a row-count, provide :count; If you're doing an update or insert, provide :affectedCount;
    #   If you're doing standard row-selection, provide :rows. Doing something illogical may work, but also may break
    #   especially for insert/update.
    # @yieldparam [Hash<Symbol,Object>] results The code block/Proc callback will be called with a single arg--a hash that
    #   has one of 2 keys:
    #   @option results [Array<Array>] :rows,:count The output rows, or the count of matching rows, or the count of affected rows.
    #     Depending on scenario as indicated by opts[:want]
    #   @option results [Exception] :err An exception that occurred.
    def doRawQuery( sql, opts= { :want => :rows }, &callback )
      retVal = true
      client = deferredRS = nil
      cb = ( block_given? ? saferRackProc( &Proc.new ) : saferRackProc( &callback ) )

      # No-go decisions
      if( cb )
        begin
          # Create EM-compliant mysql2 client
          client = getMysql2Client( opts.merge( { :emCompliant => @emCompliant } ) )
          # Arrange for EM to run query next available EM iteration
          $stderr.debugPuts(__FILE__, __method__, 'DEBUG', "#{client.class} (deferred) will execute this SQL::\n\n#{sql}\n\n")
          deferredRS = client.query(sql)
        rescue => err
          client.close rescue nil
          retVal = false
          $stderr.debugPuts(__FILE__, __method__, 'FATAL ERROR', "Failed to execute asynchronous query from _raw_ sql (provided as input).\n    Error Class: #{err.class}\n    Error Msg: #{err.message}\n    sql: #{sql.to_s[0,4096]}#{'...' if(sql.size > 4096)}\n    Error Trace:\n#{err.backtrace.join("\n")}\n\n")
          # Try to call dev callback with error info
          if(EM and EM.reactor_running?)
            EM.next_tick {
              cb.call( { :err => err } )
            }
          else # call right away, sync & from within this method (not preferred and is weird; good for testing.)
            cb.call( { :err => err } )
          end
        end

        # We do this here so as not to have it wrapped by the begin-rescue (relevant in BLOCKING mode, we don't want to wrap user's code)
        # - But only call if not rescued above; else callbacks can be called twice in BLOCKING mode.
        if( retVal )
          if( opts[:want] == :affectedCount )
            affectedCountViaCallback( deferredRS, client, sql, &cb )
          else # assume standard :rows
            #$stderr.debugPuts(__FILE__, __method__, 'TIME', "about to call resultSetViaCallback() using the deferred result set and the dev callabck")
            resultSetViaCallback( deferredRS, client, sql, &cb )
          end
        end
      else
        customErrorViaCallback( ArgumentError, "ERROR: you must supply a callback method by providing a code block (anonymous block or via &arg)", &cb )
        retVal = false
      end

      return retVal
    end

    # ----------------------------------------------------------------
    # HELPERS - not private in case useful in other code, but used by this class and its children
    # ----------------------------------------------------------------

    # SQL escapes a single value. It will be surrounded in "-quotes (which is fine even if doing numerical comparisons etc).
    #   Useful for building SQL by hand, but generally should use an existing iterative make-sql method below.
    # @param [Object] value The value to escape in order to build some SQL.
    # @param [Hash{Symbol,Object}] opts Optional. Additional options. Currently none.
    # @return [String] The escaped value, ready to put in SQL.
    def self.makeMysqlEscValue( value, opts= { :quoted => true } )
      retVal = nil
      retVal = "\"#{Mysql2::Client.escape(value.to_s)}\""
      return retVal
    end

    # Method to build a SQL set by escaping the values in items Array via Mysql2::Client.escape()
    #   Useful for constructing " where column in " clauses.
    #   List of escaped values surrounded by parentheses.
    #
    # @param [Array<String>] items The values for which to build the set string, via escaping.
    # @param [Hash{Symbol,Object}] opts Hash of additional options.
    #   @option opts [Boolean] :smartBinMode False by default, if true this will employ a 'smart binary matching' mode in order to
    #     to do CASE-SENSITIVE MATCHING on columns that are not defined as BINARY or with a _bin COLLATION. Many google'd solutions
    #     and MySQL docs indicate that you should use the COLLATE operator so that MySQL treats either operand (generally a column and a
    #     test value, or two columns) using COLLATE casting. This can mean indexes--which are based on the real, underlying collations--
    #     are not used and minimally entails a lot of collation operations of table values during search. Also if you do this, the index
    #     (even if it was selected for use) CANNOT be used to aid ORDER BY which is now slower. Using the binary collations via the
    #     BINARY operator has similar problems and certainly won't use your non-binary-based indexes! An elegant solution to this
    #     ensures that the correct index is used for identifying matching rows AND that index can be used to aid ORDER BY. This
    #     "smart binary mode" does BOTH the "{column} = {value}" matching using default collation AND the "{column} = BINARY {value}"
    #     case-sensitive condition. The first employs the default collation and indexes--which can be employed during ORDER BY if relevant--
    #     during SQL compilation & query-planning/execution to efficiently find matching rows, but then further filters the matching rows by
    #     requiring a BINARY match of the column value vs the query value. If you think the answer is simply to employ BINARY string types or
    #     binary collations, you should think about what that means for sensible ORDER BY; i.e. sensible sort is "alphabetic" (non-binary,
    #     non-binary collation) where "geek/stupid" sort is ASCII sort order. You end up having to resort sensibly in code or sort inefficiently
    #     in SQL...when you could be doing something smarter...like :smartBinMode=true
    # @returns [String] SQL set partial of the form: ('{escItem1}', '{escItem2}', '{escItem3}, ...)
    def self.makeMysqlSetStr(items, opts={ :smartBinMode => false } )
      retVal = nil
      smartBinMode = opts[:smartBinMode]
      items = [ items ] unless(items.is_a?(Array))
      raise ArgumentError, "ERROR: this method was incorrectly called; the items arg must be an Array and must have >= 1 item in makeMysqlSetStr(). Instead it was:\n    #{items.inspect}\n\n" unless(items.is_a?(Array) and items.size >= 1)
      # Build SQL set string
      lastIdx = (items.size - 1)
      sqlIO = StringIO.new()
      sqlIO << ' ( '
      items.each_index { |ii|
        sqlIO << " BINARY " if( smartBinMode ) # Each value needs this operator (will do case-sensitive/binary-collation matching)
        sqlIO << "\"#{Mysql2::Client.escape(items[ii].to_s)}\""
        sqlIO << ', ' unless(ii >= lastIdx)
      }
      sqlIO << ' ) '
      retVal = sqlIO.string
      return retVal
    end

    # Method to help build an SQL WHERE partial for searching a single field against 1+ keywords
    #   by escaping the keywords in items Array via {Mysql2::Client.escape} and wrapping them in globs (%).
    #   Can be told to match prefixes (starts with).
    #   Can specify whether to join conditions with 'AND' or 'OR'.
    # It makes a WHERE clause of the form "fieldName LIKE '%{escKeyword1}%' OR fieldName LIKE '%{escKeyword2}%'".
    # - With the optional prefixOnly flag, it will use LIKE '{escKeyword1}%' so you can look for prefixes (best anyway).
    #
    # @param [String] field Name of field to look for keyword(s) in.
    # @param [Array<Strings>] keywords Array of keywords to search field against.
    # @param [Symbol] op Either of @:and@ or @:or@, depending on whether ALL or ANY keywords must be matched
    # @param [Boolean] prefixOnly [Default: false] Match keywords against the prefix, not anywhere in the string.
    # @param [Hash{Symbol,Object}] opts Hash of additional options.
    #   @option opts [Boolean] :smartBinMode False by default, if true this will employ a 'smart binary matching' mode in order to
    #     to do CASE-SENSITIVE MATCHING on columns that are not defined as BINARY or with a _bin COLLATION. Many google'd solutions
    #     and MySQL docs indicate that you should use the COLLATE operator so that MySQL treats either operand (generally a column and a
    #     test value, or two columns) using COLLATE casting. This can mean indexes--which are based on the real, underlying collations--
    #     are not used and minimally entails a lot of collation operations of table values during search. Also if you do this, the index
    #     (even if it was selected for use) CANNOT be used to aid ORDER BY which is now slower. Using the binary collations via the
    #     BINARY operator has similar problems and certainly won't use your non-binary-based indexes! An elegant solution to this
    #     ensures that the correct index is used for identifying matching rows AND that index can be used to aid ORDER BY. This
    #     "smart binary mode" does BOTH the "{column} = {value}" matching using default collation AND the "{column} = BINARY {value}"
    #     case-sensitive condition. The first employs the default collation and indexes--which can be employed during ORDER BY if relevant--
    #     during SQL compilation & query-planning/execution to efficiently find matching rows, but then further filters the matching rows by
    #     requiring a BINARY match of the column value vs the query value. If you think the answer is simply to employ BINARY string types or
    #     binary collations, you should think about what that means for sensible ORDER BY; i.e. sensible sort is "alphabetic" (non-binary,
    #     non-binary collation) where "geek/stupid" sort is ASCII sort order. You end up having to resort sensibly in code or sort inefficiently
    #     in SQL...when you could be doing something smarter...like :smartBinMode=true
    # @return [String] Partial SQL String of the form "fieldName LIKE CONCAT('%', ?, '%') AND fieldName LIKE CONCAT('%', ?, '%')"
    def self.makeMysqlLikeSql(field, keywords, op, prefixOnly=false, opts={ :smartBinMode => false } )
      retVal = nil
      smartBinMode = opts[:smartBinMode]
      raise ArgumentError, "ERROR: value for booleanOp arg ('#{op.inspect}') in makeMultiLikeSQL() is not either :and nor :or" unless(booleanOp == :and or booleanOp == :or)
      if(field and keywords.is_a?(Array) and !keywords.empty?)
        if( smartBinMode )
          binStr = ' BINARY '
        else
          binStr = ''
        end
        # Build multi-like string
        lastIdx = (keywords.size - 1)
        sqlIO = StringIO.new()
        keywords.each_index { |ii|
          if(prefixOnly)
            sqlIO << " #{field} LIKE #{binStr} \"#{Mysql2::Client.escape(keywords[ii].to_s)}%\""
          else
            sqlIO << " #{field} LIKE #{binStr} \"%#{Mysql2::Client.escape(keywords[ii].to_s)}%\""
          end
          if(ii < lastIdx)
            if(op == :and)
              sqlIO << " AND "
            else # :or
              sqlIO << " OR "
            end
          end
        }
        retVal = sqlIO.string
      end
      return retVal
    end

    # @param [String] keyword The keyword or query string (including partial) to create
    #  a wildcard SQL partial for.
    # @param [Symbol] wildcardType Which kind of wildcard matching. Default is prefix matching
    #   using :startsWith. Also available are: :substring to match the keyword text anywhere in the
    #   column value (expensive if used in WHERE...full table scan), and :wordStart to match the keyword
    #   text at the start of "word" within the string; this option is only valid valid with matchVia=:regexp
    #   due to the need for word-boundary tokens.
    # @param [Symbol] matchVia How will the wildcard matching be done in the full SQL query you are building?
    #   Default is :like which is the most common/familiar LIKE operator and uses % glob matching. Also available
    #   is :regexp for use with MySQL RLIKE and REGEXP(); MySQL regexp support is not full perl-style posix but
    #   rather a stripped down posix with some justification for that. So :wordStart wildcard will look odd
    #   bue to lack of \b support but rather a massive nasty word-boundary token
    # @return [String] The wildcard string, for use in your full SQL
    def self.makeMysqlWildcard( keyword, wildcardType=:startsWith, matchVia=:like )
      retVal = nil
      keyword = keyword.to_s
      raise ArgumentError, "ERROR: wildcardType argument of #{wildcardType.inspect} is not an accepted Symbol. Must be :startsWith, :substring, or :wordStart." unless( wildcardType == :startsWith or wildcardType == :substring or wildcardType == :wordStart )
      raise ArgumentError, "ERROR: matchVia argument of #{matchVia.inspect} is not an accepted Symbol. Must be :like or :regexp." unless( matchVia == :like or matchVia == :regexp )
      raise ArgumentError, "ERROR: If you want to use :wordStart type matching, you must indicate a matchVia of :regexp, acknowledging you understand how match-at-start-of-a-word will be accomplished in your SQL. You can't do it with LIKE type syntax." if( wildcardType == :wordStart and matchVia != :regexp )

      escKeyword = Mysql2::Client.escape(keyword.to_s)
      if( wildcardType == :startsWith )
        retVal = ( ( matchVia == :regexp ) ? "^#{escKeyword}" : "#{escKeyword}%" )
      elsif( wildcardType == :substring )
        retVal = ( ( matchVia == :regexp ) ? ".+#{escKeyword}.+" : "%#{escKeyword}%" )
      else # wildcardType == :wordStart
        retVal = "[[:<:]]#{escKeyword}"
      end

      return retVal
    end

    # @param [Symbol] conditionOp Optional. Default: '='. How to test the column against its value when composing the
    #   conjunctions. Only sensible comparison operators such as '=', '>', '<', '!=' etc. NOTE that ALL COLUMNS will be
    #   tested with same conditionOp!! So really best makes sense for '=' and maybe '!='.
    # @param [Hash{Symbol,Object}] opts Hash of additional options.
    #   @option opts [Boolean] :smartBinMode False by default, if true this will employ a 'smart binary matching' mode in order to
    #     to do CASE-SENSITIVE MATCHING on columns that are not defined as BINARY or with a _bin COLLATION. Many google'd solutions
    #     and MySQL docs indicate that you should use the COLLATE operator so that MySQL treats either operand (generally a column and a
    #     test value, or two columns) using COLLATE casting. This can mean indexes--which are based on the real, underlying collations--
    #     are not used and minimally entails a lot of collation operations of table values during search. Also if you do this, the index
    #     (even if it was selected for use) CANNOT be used to aid ORDER BY which is now slower. Using the binary collations via the
    #     BINARY operator has similar problems and certainly won't use your non-binary-based indexes! An elegant solution to this
    #     ensures that the correct index is used for identifying matching rows AND that index can be used to aid ORDER BY. This
    #     "smart binary mode" does BOTH the "{column} = {value}" matching using default collation AND the "{column} = BINARY {value}"
    #     case-sensitive condition. The first employs the default collation and indexes--which can be employed during ORDER BY if relevant--
    #     during SQL compilation & query-planning/execution to efficiently find matching rows, but then further filters the matching rows by
    #     requiring a BINARY match of the column value vs the query value. If you think the answer is simply to employ BINARY string types or
    #     binary collations, you should think about what that means for sensible ORDER BY; i.e. sensible sort is "alphabetic" (non-binary,
    #     non-binary collation) where "geek/stupid" sort is ASCII sort order. You end up having to resort sensibly in code or sort inefficiently
    #     in SQL...when you could be doing something smarter...like :smartBinMode=true
    def self.makeDisjunctionOfConjunctions( conjList, conditionOp='=', opts={ :smartBinMode => false } )
      retVal = nil
      smartBinMode = opts[:smartBinMode]
      raise ArgumentError, "ERROR: The conjunction list is not an Array of 1+ Hashes keyed by 1+ column names. conjList:\n#{conjList.inspect}\n\n" unless( conjList.is_a?(Array) and !conjList.empty? and conjList.first.is_a?(Hash) and !conjList.first.empty? )
      if( smartBinMode )
        binStr = ' BINARY '
      else
        binStr = ''
      end
      sql = ' ( ' # BEGIN outer wrapper around all disjunctions
        conjList.each_index { |jj|
          conj = conjList[jj]
          sql << ' ( ' # BEGIN inner wrapper around conjuntion
            conj.keys.each_index { |ii|
              col = conj.keys[ii]
              val = conj[col]
              sql << ' ( ' # BEGIN condition wrapper
                sql << " #{col} #{conditionOp} #{binStr} \"#{Mysql2::Client.escape(val.to_s)}\" "
              sql << ' ) ' # END condition wrapper
              sql << ' AND ' unless( ii >= (conj.keys.size - 1) )
            }
          sql << ' ) ' # END inner wrapper around conjuntion
          sql << ' OR ' unless( jj >= (conjList.size - 1) )
        }
      sql << ' ) ' # END outer wrapper around all disjunctions
      return sql
    end

    # Method to build an SQL CSV values list  by escaping the values in items Array via Mysql2::Client.escape().
    #   Suitable for doing batch insert SQL.
    # e.g. It will create a string like:
    #   @('{escItem1}', '{escItem2}', '{escItem3}'), ('{escItem4}', '{escItem5}', '{escItem6}')@
    #
    # @param [Array<String>] items FLAT Array of values from which to prepare partial.
    # @param [Fixnum] numValsPerRec Number of values per record.
    # @param [Boolean] reserveId [Default=true] Indicates whether first column is for an auto-incrementing id and thus
    #   the values should be auto-preceded by a 'null' to make this column to the right thing (esp. when inserting new data)
    #   into table with auto-increment first column).
    # @param [Hash{Symbol,Object}] opts Additional options used to build the multi-values SQL partial.
    # @return [String] Partial SQL String of the form @('{escItem1}', '{escItem2}'), ('{escItem3}', '{escItem4}'), ('{escItem5}', '{escItem6}')@
    # @raise ArgumentError If supply empty items or invalid numValsPerRec
    def self.makeMysqlValuesStr(items, numValsPerRec, reserveId=true, opts={} )
      retVal = nil
      raise ArgumentError, "ERROR: must have at least 1 item and numBindVarsPerValue can't be < 1" if(items.nil? or items.empty? or numValsPerRec < 1)
      # Compute these once
      numValues = (items.size / numValsPerRec)
      lastValIdx = (numValues - 1)
      lastFieldIdx = (numValsPerRec - 1)
      # Build SQL values string
      sqlIO = StringIO.new()
      itemIdx = 0
      numValues.times { |ii|
        sqlIO << ' ( '
        sqlIO << ' null, ' if(reserveId)
        numBindVarsPerValue.times { |jj|
          value = items[itemIdx]
          sqlIO << "\"#{Mysql2::Client.escape(value.to_s)}\""
          sqlIO << ', ' unless(jj >= lastFieldIdx)
          itemIdx += 1
        }
        sqlIO << ' )'
        sqlIO << ', ' unless(ii >= lastValIdx)
      }
      retVal = sqlIO.string
      return retVal
    end

    # Method to help build a key=value SQL partial by escaping the values in items Array via Mysql2::Client.escape() .
    #   Commonly used for SET or WHERE clauses.
    #   Example:      @fields = ['colX', 'colY'] ; op = :and@
    #   Would return: @"colX = '{escVal1}' AND colY = '{escVal2}'"@
    #
    # @param [Array<String>, Hash{String,String}] fields Either: (1) Array of field names to be used with 2nd argument, the
    #   the matching list of values for the fields; OR (2) A field=value Hash and the 2nd argument is @nil@.
    #   the matching list of values for the fields; OR (2) A field=value Hash and the 2nd argument is @nil@.
    # @param [Array<String>, nil] items Array for values, one per field in the first argument OR nil if the first argument
    #   is a field=value Hash.
    # @param [Symbol] op Whether field=value pairs should be joined by 'AND' (@:and@) or 'OR' (@:or@) or ',' (@:comma@).
    #   The latter is useful for in 'UPDATE ... SET' sql.
    # @param [Hash{Symbol,Object}] opts Hash of additional options.
    #   @option opts [Boolean] :smartBinMode False by default, if true this will employ a 'smart binary matching' mode in order to
    #     to do CASE-SENSITIVE MATCHING on columns that are not defined as BINARY or with a _bin COLLATION. Many google'd solutions
    #     and MySQL docs indicate that you should use the COLLATE operator so that MySQL treats either operand (generally a column and a
    #     test value, or two columns) using COLLATE casting. This can mean indexes--which are based on the real, underlying collations--
    #     are not used and minimally entails a lot of collation operations of table values during search. Also if you do this, the index
    #     (even if it was selected for use) CANNOT be used to aid ORDER BY which is now slower. Using the binary collations via the
    #     BINARY operator has similar problems and certainly won't use your non-binary-based indexes! An elegant solution to this
    #     ensures that the correct index is used for identifying matching rows AND that index can be used to aid ORDER BY. This
    #     "smart binary mode" does BOTH the "{column} = {value}" matching using default collation AND the "{column} = BINARY {value}"
    #     case-sensitive condition. The first employs the default collation and indexes--which can be employed during ORDER BY if relevant--
    #     during SQL compilation & query-planning/execution to efficiently find matching rows, but then further filters the matching rows by
    #     requiring a BINARY match of the column value vs the query value. If you think the answer is simply to employ BINARY string types or
    #     binary collations, you should think about what that means for sensible ORDER BY; i.e. sensible sort is "alphabetic" (non-binary,
    #     non-binary collation) where "geek/stupid" sort is ASCII sort order. You end up having to resort sensibly in code or sort inefficiently
    #     in SQL...when you could be doing something smarter...like :smartBinMode=true
    # @return [String] Partial SQL String of the form @"colX = '{escVal1}' AND colY = '{escVal2}'"@
    # @raise [ArgumentError] If field and/or items not correctly present or have different sizes.
    def self.makeMysqlKeyValuePairsSql(fields, items, op, opts={ :smartBinMode => false } )
      col2val = fields
      fields = [fields] unless(fields.is_a?(Array))
      smartBinMode = opts[:smartBinMode]

      # No-go decisions
      raise ArgumentError, "ERROR: If the first argument is a col2val Hash, then the 2nd argument MUST be nil to assert you understand what you are doing. Right now, we must assume you don't know." if(col2val.is_a?(Hash) and !items.nil?)
      raise ArgumentError, "ERROR: fields Array and items Array must have same size" unless( ( fields.is_a?(Array) and items.is_a?(Array) and (fields.size == items.size) ) or ( col2val.is_a?(Hash) ) )
      raise ArgumentError, "ERROR: columns cannot have weird characters nor require quoting to be used. So even spaces are not allowed. And certainly nothing beyond 0-9,a-z,A-Z$_." if( fields.any?{|cc| cc =~ /[^0-9,a-z,A-Z$_]/ } )

      # Get matching fields and values array (we don't assume that Hash#keys and Hash#values returns in paired-up order)
      if(col2val.is_a?(Hash))
        fields, items = [], []
        col2val.each_key { |kk| fields << kk ; items << col2val[kk] }
      end

      # In case-sensitive mode (via BINARY operator ; i.e. binary collation), we use BINARY on the RHS operand which is a value
      #   (not a column). Thus there are O(C) BINARY operations where C is the number of field-values in the SQL, rather than
      #   O(N)*O(C) where N is the number of rows and C is the number of coluns being matched..
      if( smartBinMode )
        binStr = ' BINARY '
      else
        binStr = ''
      end

      sep = case op
        when :and then ' and '
        when :or then ' or '
        when :comma then ', '
        else raise ArgumentError, "ERROR: value for seperatorSym arg ('#{seperatorSym.inspect}') in #{__method__}() is not either :and nor :or nor :comma"
      end
      lastIdx = (fields.size - 1)
      sqlIO = StringIO.new()
      fields.each_index { |ii|
        field = fields[ii]
        item = items[ii]
        sqlIO << "#{field} = #{binStr} \"#{Mysql2::Client.escape(item.to_s)}\""
        sqlIO << sep unless(ii >= lastIdx)
      }
      return sqlIO.string
    end

    # Method to build a list of column names SQL partial.
    # @note We have restrictions to make column names sensible and safe. Weird characters (like unicode) that are technically allowed in
    #   column names, especially quoted column names (UGHH!), by MySQL are munged to normal and limited ASCII for security.
    #   Genboree does not use, nor will it use, weird chars in column names so these are clearly invalid.
    # @note Although we could build the column list with BINARY in front of each column name, say for case-sensitive searching s
    #   the multiple column names, for reasons explained in many methods above, this is not a great idea. So :smartBinMode is
    #   not supported here (because it's not 'smart') but if needed for some particular case, it could be add so each
    #   column is checked vs its BINARY collation version not the native storage/indexed version.
    # @param [Array<String>] columsn The column names to turn into a list
    # @param [Hash{Symbol,Object}] opts Hash of additional options.
    # @returns [String] SQL set partial of the form: ('{escItem1}', '{escItem2}', '{escItem3}, ...)
    # @raise ArgumentError If you didn't supply acceptable column names.
    def self.makeMysqlColumnListSql(columns, opts={} )
      retVal = nil
      columns = [ columns ] unless(columns.is_a?(Array))
      columns.map! { |cc| cc.to_s.strip }
      raise ArgumentError, "ERROR: the columns arg must be an Array and must have size >= 1 column." unless(columns.is_a?(Array) and columns.size >= 1)
      raise ArgumentError, "ERROR: columns cannot have weird characters nor require quoting to be used. So even spaces are not allowed. And certainly nothing beyond 0-9,a-z,A-Z$_." if( columns.any?{|cc| cc =~ /[^0-9,a-z,A-Z$_]/ } )
      # Build SQL set string
      retVal = columns.join(', ')
      return retVal
    end

    # Method to build an SQL partial comprised of series of column-setting expressions of the form: @{col} = values({col})@. This
    #   is exactly what is needed after an @ON DUPLICATE KEY UPDATE@ qualifier when doing, say, upserts.
    # @note We have restrictions to make column names sensible and safe. Weird characters (like unicode) that are technically allowed in
    #   column names, especially quoted column names (UGHH!), by MySQL are munged to normal and limited ASCII for security.
    #   Genboree does not use, nor will it use, weird chars in column names so these are clearly invalid.
    # @param [Array<String>] columns The column names to turn into a set of @{col} = values({col})@ expresssions.
    # @param [Hash{Symbol,Object}] opts Hash of additional options.
    # @returns [String] SQL set partial of the form: @{col} = values({col})@
    # @raise ArgumentError If you didn't supply acceptable column names.
    def self.makeMysqlOnDupUpdateSql(columns, opts={})
      retVal = nil
      columns = [ columns ] unless(columns.is_a?(Array))
      columns.map! { |cc| cc.to_s.strip }
      raise ArgumentError, "ERROR: the columns arg must be an Array and must have size >= 1 column." unless(columns.is_a?(Array) and columns.size >= 1)
      raise ArgumentError, "ERROR: columns cannot have weird characters nor require quoting to be used. So even spaces are not allowed. And certainly nothing beyond 0-9,a-z,A-Z$_." if( columns.any?{|cc| cc =~ /[^0-9,a-z,A-Z$_]/ } )
      # Build SQL set string
      lastIdx = (columns.size - 1)
      sqlIO = StringIO.new()
      sep = ', '
      columns.each_index { |ii|
        column = columns[ii]
        sqlIO << "#{column} = values(#{column})"
        sqlIO << sep unless(ii >= lastIdx)
      }
      return sqlIO.string
    end

    # Builds the appropriate desired fields (output colums) SQL partial using info in opts Hash.
    # @note We have restrictions to make column names sensible and safe. Weird characters (like unicode) that are technically allowed in
    #   column names, especially quoted column names (UGHH!), by MySQL are munged to normal and limited ASCII for security.
    #   Genboree does not use, nor will it use, weird chars in column names so these are clearly invalid.
    # @param [Hash{Symbol,Object}] opts Hash of additional options for the query. Common keys are:
    #   @option opts [Array<String>] :desiredFields Array of desired output fields. If missing, then all.
    #   @option opts [Boolean] :distinct True if output rows should be distinct.
    # @return [String] The output columns SQL partial, suitable for use in a SELECT, say.
    # @raise ArgumentError If you didn't supply acceptable column names.
    def desiredFieldsSqlPartial( opts )
      desiredFieldsStr = '*'
      desiredFields = opts[:desiredFields]
      if(desiredFields)
        desiredFields = [ desiredFields ] unless(desiredFields.is_a?(Array))
        desiredFields.map! { |cc| cc.to_s.strip }
        # $stderr.debugPuts(__FILE__, __method__, 'DEBUG', "BEFORE: desiredFields: #{desiredFields.inspect}")
        raise ArgumentError, "ERROR: columns cannot have weird characters nor require quoting to be used. So even spaces are not allowed. And certainly nothing beyond 0-9,a-z,A-Z$_." if( desiredFields.any?{|cc| cc =~ /[^0-9a-zA-Z$_]/ } )
        if(desiredFields)
          # Make sure desiredFields is an Array (e.g. maybe just 1 field and a String)
          desiredFields = [ desiredFields ] unless(desiredFields.is_a?(Array))
          # Make SQL list of fields
          desiredFieldsStr = desiredFields.join(',')
        else
          desiredFieldsStr = '*'
        end
        #$stderr.debugPuts(__FILE__, __method__, 'DEBUG', "desiredFieldsStr: #{desiredFieldsStr.inspect}")
      end
      return desiredFieldsStr
    end

    # Make a "FIELD( {col}, values....)" type SQL partial out of array of string and optional
    #   sort keys for ordering those string (1:1)
    def self.fieldSql( column, values, sortKeys=nil)
      values = values.map { |vv| vv.to_s }
      if( sortKeys )
        values = values.sort { |aa,bb|
          aaIdx, bbIdx = values.index(aa), values.index(bb)
          cmp = (sortKeys[aaIdx].downcase <=> sortKeys[bbIdx].downcase)
          cmp = (sortKeys[aaIdx] <=> sortKeys[bbIdx]) if( cmp == 0 )
          cmp
        }
      end
      values = values.map { |vv| GbDb::DbConnection.makeMysqlEscValue( vv ) }
      retVal = "FIELD( #{column}, #{values.join(', ')} )"
      return retVal
    end

    # Builds the appropriate distinct SQL partial using info in opts Hash.
    # @param [Hash{Symbol,Object}] opts Hash of additional options for the query. Common keys are:
    #   @option opts [Array<String>] :desiredFields Array of desired output fields. If missing, then all.
    #   @option opts [Boolean] :distinct True if output rows should be distinct.
    # @return [String] The distinct SQL partial, suitable for use in a SELECT, say.
    def distinctSqlPartial( opts )
      (opts[:distinct] ? 'distinct' : '')
    end

    # Builds the appropriate ORDER BY SQL partial using info in opts Hash.
    # @note We have restrictions to make column names sensible and safe. Weird characters (like unicode) that are technically allowed in
    #   column names, especially quoted column names (UGHH!), by MySQL are munged to normal and limited ASCII for security.
    #   Genboree does not use, nor will it use, weird chars in column names so these are clearly invalid.
    # @note If you have :desiredFields then ALL :orderBy columns MUST also be in the :desiredFields array.
    # @param [Hash{Symbol,Object}] opts Hash of additional options for the query. Common keys are:
    #   @option opts [Array<String>] :desiredFields Array of desired output fields. If missing, then all.
    #   @option opts [Boolean] :distinct True if output rows should be distinct.
    # @return [String] The output columns SQL partial, suitable for use in a SELECT, say.
    # @raise ArgumentError If you didn't supply acceptable column names or some order by columns are not present in
    #   desiredFields or the direction Symbol for any order by column is not either @:asc@ or @:desc@.
    def orderBySqlPartial( opts )
      sql = ''
      # Get the order by hash
      orderBy = opts[:orderBy]
      if(orderBy)
        # Normalize orderBy hash
        normOrderBy = {}
        orderBy.each_key { |col| ncol = col.to_s.strip ; normOrderBy[ncol] = orderBy[col] }
        # Get any desired output field info (if present)
        desiredFields = opts[:desiredFields]
        if(desiredFields)
          desiredFields = [ desiredFields ] unless(desiredFields.is_a?(Array))
          desiredFields.map! { |cc| cc.to_s.strip }
        end

        # No-go desisions
        raise ArgumentError, "ERROR: columns cannot have weird characters nor require quoting to be used. So even spaces are not allowed. And certainly nothing beyond 0-9,a-z,A-Z$_." if( ( desiredFields and desiredFields.any?{|cc| cc =~ /[^0-9a-zA-Z$_]/} ) or normOrderBy.keys.any?{|cc| cc =~ /[^0-9a-zA-Z$_]/} )
        raise ArgumentError, "ERROR: only direction symbold :asc and :desc can be used for a column in your :orderBy hash." unless( normOrderBy.values.all?{|vv| (vv == :asc or vv == :desc) } )
        raise ArgumentError, "ERROR: all columns in your :orderBy hash must also be in your :desiredFields list (if provided). No exceptions." if( desiredFields.is_a?(Array) and normOrderBy.keys.any?{|cc| !(desiredFields.include?(cc)) } )

        sql = 'ORDER BY '
        cc = 0
        normOrderBy.each_key { |col|
          dir = ( (normOrderBy[col] == :desc) ? 'DESC' : 'ASC' )
          sql << "#{col} #{dir}"
          sql << ', ' unless(cc <= (normOrderBy.size - 1) )
          cc += 1
        }
      end

      return sql
    end

    # ----------------------------------------------------------------
    # INTERNAL HELPERS
    # ----------------------------------------------------------------

    # Arrange to return a result set obtained from client, via a callback Proc
    #   Automatically handle the callback registration for EM-based NON-BLOCKING mode or
    #   immediate manuall calling of callback code ourselves for BLOCKING mode.
    #   Wrap the callback arg as a Hash with either :rows key or :err key.
    # @param [Array<Hash>] resultSet The result set to return.
    # @param [Mysql2::Client, Mysql2::EM::Client] client The client that gave the result set (will be closed)
    # @param [String] sql The SQL statment that was already executed (for error logging purposes when setting up errback).
    # @yieldparam [Hash<Symbol,Object>] results The code block/Proc callback will be called with a single arg--a hash that
    #   has one of 2 keys:
    #   @option results [Array<Array>] :rows The output rows.
    #   @option results [Exception] :err An exception that occurred.
    def resultSetViaCallback( resultSet, client, sql, &callback )
      cb = ( block_given? ? saferRackProc( &Proc.new ) : saferRackProc( &callback ) )
      # Next, register [or do, if blocking] callbacks for when event loop does our query
      if( resultSet.respond_to?(:callback) ) # Then have deferred result set as hoped. Register callbacks for later loop interation.
        #$stderr.debugPuts(__FILE__, __method__, 'TIME', "The resultSet is a deferred kind, it has a 'callback' method to use for that")
        # - Success callback
        resultSet.callback { |rs|
          client.close rescue nil
          $stderr.debugPuts(__FILE__, __method__, 'TIME', "Query done. Call dev callback and provide result set")
          cb.call( { :rows => rs.respond_to?(:entries) ? rs.entries : [] } )
        }
        # - Failure callback
        resultSet.errback { |err|
          client.close rescue nil
          $stderr.puts "FATAL ERROR: Failed to execute SQL statement.\n    Error Class: #{err.class}\n    Error Msg: #{err.message}\n    sql: #{sql.to_s[0,1024]}\n    Error Trace:\n#{err.backtrace.join("\n")}\n\n"
          cb.call( { :err => err } )
        }
      else # looks like blocking and/or no EM reactor running
        # No callback registration, just call immediately.
        $stderr.debugPuts(__FILE__, __method__, 'WARNING', "Why are you calling this in BLOCKING mode? Bad dev! Do it properly, in NON-BLOCKING mode.") if( @emCompliant )
        client.close rescue nil
        cb.call( { :rows => resultSet.respond_to?(:entries) ? resultSet.entries : [] } )
      end
    end

    # Arrange to return the count of affected rows from an UPDATE, INSERT, or DELETE as obtained from client, via a callback Proc.
    #   Automatically handle the callback registration for EM-based NON-BLOCKING mode or
    #   immediate manual calling of callback code ourselves for BLOCKING mode.
    #   Wrap the callback arg as a Hash with either :rows key or :err key.
    # @param [Array<Hash>] resultSet The [deferred] result set.
    # @param [Mysql2::Client, Mysql2::EM::Client] client The client that performed the query (will be closed).
    # @param [String] sql The SQL statment that was already executed (for error logging purposes when setting up errback).
    # @yieldparam [Hash<Symbol,Object>] results The code block/Proc callback will be called with a single arg--a hash that
    #   has one of 2 keys:
    #   @option results [Fixnum, nil] :count The number of affected rows, from the client. Or nil if client has no affected_rows() method.
    #   @option results [Exception] :err An exception that occurred.
    def affectedCountViaCallback( resultSet, client, sql, &callback )
      cb = ( block_given? ? saferRackProc( &Proc.new ) : saferRackProc( &callback ) )
      # Next, register [or do, if blocking] callbacks for when event loop does our query
      if( resultSet.respond_to?(:callback) ) # Then have deferred result set as hoped. Register callbacks for later loop interation.
        # - Success callback
        resultSet.callback { |rs|
          count = ( client.respond_to?(:affected_rows) ? client.affected_rows : nil )
          client.close rescue nil
          cb.call( { :count => count } )
        }
        # - Failure callback
        resultSet.errback { |err|
          client.close rescue nil
          $stderr.puts "FATAL ERROR: Failed to execute SQL statement.\n    Error Class: #{err.class}\n    Error Msg: #{err.message}\n    sql: #{sql.to_s[0,1024]}\n    Error Trace:\n#{err.backtrace.join("\n")}\n\n"
          cb.call( { :err => err } )
        }
      else # looks like blocking and/or no EM reactor running
        # No callback registration, just call immediately.
        $stderr.debugPuts(__FILE__, __method__, 'WARNING', "Why are you calling this in BLOCKING mode? Bad dev! Do it properly, in NON-BLOCKING mode.")
        count = ( client.respond_to?(:affected_rows) ? client.affected_rows : nil )
        client.close rescue nil
        cb.call( { :count => count ? count : nil } )
      end
    end

    def self.customErrorViaCallback( rackCallback, errClass, errMsg, &callback )
      retVal = false # bad things have happened
      cb = ( block_given? ? SaferRackProc.withRackCallback( rackCallback, &Proc.new ) : SaferRackProc.withRackCallback( rackCallback, &callback ) )
      # Did we get a non-nill callback to use (or is nil callback the error?)
      if( cb )
        begin
          err = errClass.new( errMsg )
          err.set_backtrace( caller )
        rescue Exception => eerr # couldn't set up error callback, ugh; arrange to capture THAT fact at least
          msg = "Trying to report custom exception about application error itself resulted in an error! Important to first address failed error reporting.\n    Error Class: #{err.class}\n    Error Msg: #{err.message}\n    sql: #{sql.to_s[0,1024]}\n    Error Trace:\n#{err.backtrace.join("\n")}\n\n"
          $stderr.debugPuts(__FILE__, __method__, 'FATAL ERROR', msg)
          err = eerr
        end
        # If EM running, call next tick ; else call now
        if(EM and EM.reactor_running? and @emCompliant)
          EM.next_tick {
            cb.call( { :err => err } )
          }
        else # No event loop, so call callback immediately
          cb.call( { :err => err } )
        end
      else # the problem is that there is no callback at all!
        $stderr.debugPuts(__FILE__, __method__, '!!MISSING CALLBACK!!', "Dev didn't provide REQUIRED callback. Trying to arrange to reply to client with this as the error.")
        # Trigger attempt to directly reply
        cb = SaferRackProc.withRackCallback(rackCallback) {
          raise errClass, errMsg
        }
        # Actually the argument here is useless. We're replying on the raise to trigger rescue-and-response behaviour.
        cb.call( { :err => errClass.new(errMsg) } )
      end

      return retVal
    end

    def customErrorViaCallback( errClass, errMsg, &callback )
      cb = ( block_given? ? saferRackProc( &Proc.new ) : saferRackProc( &callback ) )
      self.class.customErrorViaCallback( @rackCallback, errClass, errMsg, &cb )
    end
  end
end