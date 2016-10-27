#!/usr/bin/env ruby

require "json"
require "brl/genboree/rest/helpers"
require "brl/genboree/rest/data/entity"

#--
module BRL ; module Genboree ; module REST ; module Data
module Builders
#++

  # Builder
  #  This class defines the core of the framework for the Boolean Query Engine.
  #  The class is meant as an abstract superclass for concrete subclasses to 
  #  define the necessary constants and a few methods in order to provide the
  #  ability to apply Boolean Queries to a type of resource (typically a
  #  resource that normally returns some type of DataEntityList).  The following
  #  items must be defined in order to create a properly functioning subclass:
  #
  # +Constants+
  # * PRIMARY_TABLE
  # * PRIMARY_ID
  # * SECONDARY_TABLE (optional)
  # * AVP_TABLES
  # * AVP_IDS
  # * CORE_FIELDS
  #
  # +Methods+
  # * buildTextEntities(DBUtil dbu, Hash dbRows, String refBase)
  # * buildDataEntities(DBUtil dbu, Hash dbRows, String refBase)
  # * filterByPermissions(DBUtil dbu, Hash dbRows, Integer userId)
  # * getName(Hash dbRows)
  #
  # Each of these items has detailed description for how to implement them for
  # proper concrete subclasses in their own RDoc comments.
  class Builder

    # Gets set by subclasses that cannot return an +EntityList+ when an error
    # occurs
    attr_accessor :error

    MAX_BUFFER_SIZE = 16_000

    # The PRIMARY_TABLE constant simply provides the name of the table on which
    # a subclass will operate (on which it applies the Boolean Query)
    PRIMARY_TABLE = "table"

    # The PRIMARY_KEY constant is the name of the primary key id in the 
    # PRIMARY_TABLE.  It does not have to be an int, varchar is fine.
    PRIMARY_ID = "id"
    
    # If defined (!nil) SECONDARY_TABLES is meant to be a Hash.  In order for
    # Builder class to properly use this constant, the Hash should be setup as
    # follows:
    # * Each key should be the name of an additional table that provides fields
    #   that should be included in the queryable fields for the Boolean Query
    # * The value for the keys should be an SQL constraint that allows a table
    #   join to produce a single row for each PRIMARY_KEY.  If this is not
    #   possible (in the case of a 1-to-many relationship) then this table
    #   cannot be supported as a secondary table (with the exception of AVPs).
    SECONDARY_TABLES = nil

    # If the entity has the 3 necessary data tables to support AVPs, then this
    # constant represents a Hash with 3 keys:
    # * names => the name of the table that stores the attribute name data.
    # * values => the name of the table that stores the values data.
    # * join => the name of the table that stores the 3-way id join data.
    AVP_TABLES = { "names" => "tableAttrNames", "values" => "tableAttrValues", "join" => "table2attributes" }

    # If the entity has unconventional naming in its AVP tables, the AVP_IDS
    # constant can be used to override the normal naming scheme (single table
    # name + "_id").  The ids are in the following order:
    #   [ join.primaryid, join.nameid, names.id, join.valueid, values.id ]
    # For example, in the case of annotation, AVP_IDS would be:
    #   [ "fid", "attNameId", "attNameId", "attValueId", "attValueId" ]
    AVP_IDS = nil

    # This constant is expected to be a Hash with the following format:
    # * The keys are either 1.) the special key primary, or 2.) the name of the
    #   table from the SECONDARY_TABLES array (one of the keys of that Hash)
    # * The values are expected to be an Array of Strings.  Each string should
    #   be the name of a field from the table used as the key.  Anything that
    #   is defined in this array becomes a queryable field.  Anything that
    #   is not defined in these fields will be assumed to be the name of an
    #   attribute and the AVPs will be searched for matches on this name.
    # NOTE: Make sure to include the PRIMARY_ID as one of the fields of the 
    # primary array or the code will not work properly.
    CORE_FIELDS = { "primary" => [], "secondary" => [] }

    # Must be defined in order to use the methods in GenboreeDBHelper
    DbRec = Struct.new(:dbName, :ftypeid, :dbType)

    # Default constructor builds an empty refbase.  Usually this is done here.
    # [+url+] The portion of the URI that this builder has matched with its
    #   pattern() method (thus it should be able to process)
    def initialize(url)
      @refBase = ""
    end

    # Helper method to recurse the body of a JSON query object to determine
    # if the body of the query references an AVP attributes.
    # [+body+] The Ruby Hash representing the translated JSON query.
    # [+returns+] +false+ if all named attributes are part of the +CORE_FIELDS+
    #   Array for this class, +true+ otherwise.
    def checkForAvps(body)
      # This is necessary just to make the recursion easier
      return false if(body.class == Array and body.length == 0)

      if(body.class == Array)
        return (checkForAvps(body[0]) or checkForAvps(body[1..body.length]))
      elsif(body['attribute'])
        # Base case - we were passed a clause
        core = false
        self.class::CORE_FIELDS.each{ |table, list|
          core = true if(list.include?(body['attribute']))
        }
        return !core
      elsif(body['body'])
        # Similar base case, we were passed a statement
        return checkForAvps(body['body'])
      end

      # Something went wrong
      $stderr.puts("BRL::Genboree::REST::Data::Builders::Builder.checkForAvps: Improperly formed query JSON, not an array and missing 'body' or 'attribute' keys")
      return false
    end

    # Helper method to simply translate a single clause into resulting SQL code
    # that can be used to apply to the tables listed in the PRIMARY_TABLE and
    # SECONDARY_TABLES constants.  Every clause returned will be surrounded by
    # parentheses so that it can be treated like an atom.
    # [+clause+] A Hash representing the clause translated from the JSON object
    # [+return+] The SQL constraint (to be used in the WHERE part of a statement)
    #   surrounded by parentheses so that is can be used atomically.
    def clauseToSql(clause)
      # Handle the prefix and left side of the clause translations
      attribute = clause['attribute'].gsub(/\\/, "\\").gsub(/'/, "\\'")
      avp = true
      self.class::CORE_FIELDS.each { |name, list|
        avp = false if(list.include?(clause['attribute']))
      }
      prefix = left = ""
      if(avp)
        # Handle AVP
        prefix = "a.name='#{attribute}' AND "
        if(clause['value'].is_a?(Numeric))
          # Handle AVP with casting
          # NOTE: This is imperfect when dealing with string values.  Any text
          #   (i.e. string that cannot be case, for example "abc" or "ab2") will
          #   be cast to the value 0.  This means when comparing for "attr == 0",
          #   "attr > -1", etc. you will not get the proper results.  I have no
          #   solution for this issue at this time.
          left = "cast(v.value as signed)"
        else
          left = "v.value"
        end
      else
        # Handle core field
        prefix = ""
        table = "p"

        # Check the table name to query from (default to primary table)
        self.class::CORE_FIELDS.each { |name, list|
          if(list.include?(clause['attribute']))
            table = name unless(name == "primary")
          end
        }
        left = "#{table}.#{attribute}"
      end

      # Handle operation and right side of the clause translations
      if(clause['value'].is_a?(String))
        value = clause['value'].gsub(/\\/, "\\").gsub(/'/, "\\'")
      elsif(clause['value'].is_a?(Numeric))
        value = clause['value']
      end

      # Process ranges properly
      if(value.to_s.index(".."))
        values = value.split("..")
        values[0] = values[0].to_f if(values[0].to_f.to_s == values[0])
        values[0] = values[0].to_i if(values[0].to_i.to_s == values[0])
        values[1] = values[1].to_f if(values[1].to_f.to_s == values[1])
        values[1] = values[1].to_i if(values[1].to_i.to_s == values[1])
      else
        values = []
      end

      sql = ""
      case clause['op']
      when "==":
        if(value.is_a?(Numeric))
          sql = "#{left} = #{value}" if(value.is_a?(Numeric))
        elsif(value.is_a?(String) and clause['case'] == "sensitive")
          sql = "#{left} = '#{value}'" if(value.is_a?(String))
        else
          sql = "#{left} like '#{value}'" if(value.is_a?(String))
        end
      when "=~":
        sql = "#{left} rlike '#{value}'"
      when "has":
        if(clause['case'] == "sensitive")
          sql = "#{left} like binary '%#{value}%'"
        else
          sql = "#{left} like '%#{value}%'"
        end
      when "startsWith":
        if(clause['case'] == "sensitive")
          sql = "#{left} like binary '#{value}%'"
        else
          sql = "#{left} like '#{value}%'"
        end
      when "endsWith":
        if(clause['case'] == "sensitive")
          sql = "#{left} like binary '%#{value}'"
        else
          sql = "#{left} like '%#{value}'"
        end
      when ">", ">=", "<", "<=", "like":
        sql = "#{left} #{clause['op']} #{value}" if(value.is_a?(Numeric))
        sql = "#{left} #{clause['op']} '#{value}'" if(value.is_a?(String))
      when "()":
        sql = "#{left} > #{values[0]} AND #{left} < #{values[1]}" if(values[0].is_a?(Numeric) and values[1].is_a?(Numeric))
        sql = "#{left} > '#{values[0]}' AND #{left} < '#{values[1]}'" if(values[0].is_a?(String) or values[1].is_a?(String))
      when "(]":
        sql = "#{left} > #{values[0]} AND #{left} <= #{values[1]}" if(values[0].is_a?(Numeric) and values[1].is_a?(Numeric))
        sql = "#{left} > '#{values[0]}' AND #{left} <= '#{values[1]}'" if(values[0].is_a?(String) or values[1].is_a?(String))
      when "[)":
        sql = "#{left} >= #{values[0]} AND #{left} < #{values[1]}" if(values[0].is_a?(Numeric) and values[1].is_a?(Numeric))
        sql = "#{left} >= '#{values[0]}' AND #{left} < '#{values[1]}'" if(values[0].is_a?(String) or values[1].is_a?(String))
      when "[]":
        sql = "#{left} >= #{values[0]} AND #{left} <= #{values[1]}" if(values[0].is_a?(Numeric) and values[1].is_a?(Numeric))
        sql = "#{left} >= '#{values[0]}' AND #{left} <= '#{values[1]}'" if(values[0].is_a?(String) or values[1].is_a?(String))
      else
        $stderr.puts("BRL::Genboree::REST::Data::Builders::Builder.clauseToSql(): ERROR, there is an unknown operator #{clause['op']} in your Boolean Query")
        sql = "TRUE"
      end

      # Return translation
      return "(#{prefix} #{sql})"
    end

    # A recursive helper method that translates a Ruby Hash (representing the
    # JSON definition of a Boolean Query) into an SQL statement.  This is done
    # by recursively processing the clauses and adding a set of parenthesis
    # every time that we recurse.  Arrays of clauses are separated by the
    # boolean operators AND or OR depending on the value of "bool".
    # [+query+] A Hash representing the query translated from the JSON object
    # [+returns+] The WHERE clause of an SQL statement representing the 
    #   constraints defined by the Boolean Query from +query+.  Note that this
    #   SQL is not a fully valid SQL, just a section that can be used in the
    #   WHERE clause of an SQL statement.
    def queryToSql(query)
      if(query.class == Hash and query['attribute'])
        # Clause
        #   base case - translate this clause into an sql clause
        return clauseToSql(query)
      elsif(query.class == Hash and query['body'])
        # Statement
        #   handle a statement by recursing through its body, nesting all elements
        inverse = (query['not']) ? "!" : ""
        return "#{inverse}#{queryToSql(query['body'])}"
      elsif(query.class == Array)
        # Body of a Statement - Array of clauses / statements
        #   Handle each element recursively, adding operators as needed
        sql = ""
        query.each { |elem|
          bool = elem['bool']
          if(query.rindex(elem) == query.length - 1)
            sql += queryToSql(elem)
          elsif(bool.nil?)
            $stderr.puts("BRL::Genboree::REST::Data::Builders::Builder.queryToSql(): Missing boolean operator from statement in Array (Badly formed query at index #{query.rindex(elem)})")
          else
            sql += "#{queryToSql(elem)} #{bool} "
          end
        }
        return "(#{sql})"
      end
    end

    # Helper method that translates a Boolean Query from the Ruby Hash that
    # represents the original JSON Object into a valid SQL statement.
    # [+query+] A Hash representing the query translated from the JSON object
    # [+constraints+] Optional, any additionally constraints to be placed on
    #   the query in addition to those defined by the Boolean Query object.
    #   Ex] when querying for trackAnnos, we actually use the same table
    #   definitions and other information as the dbAnnos queries, but we 
    #   simply add the constraint (ftype.fsource="A" AND ftype.fmethod="B").
    #   There is an example of this in the TrackAnnosBuilder.
    # [+returns+] A valid SQL statement (String)
    def buildSql(query, constraints = nil)
      # First check if any non-core attributes are used in this query
      avp = checkForAvps(query)

      # Build our field list
      fields = ""
      self.class::CORE_FIELDS.each{ |table, list|
        tableName = (table == "primary" ? "p" : table)
        list.each{ |field|
          fields += (fields.length == 0 ? "#{tableName}.#{field}" : ", #{tableName}.#{field}")
        }
      }

      # Build our tables list (primary / secondary not including AVP)
      tables = "#{self.class::PRIMARY_TABLE} p"
      constraints = "" if(constraints.nil? and !self.class::SECONDARY_TABLES.nil?)
      unless(self.class::SECONDARY_TABLES.nil?)
        self.class::SECONDARY_TABLES.each{ |table, constraint|
          tables += ", #{table}"
          constraints += (constraints.length == 0 ? constraint : " AND #{constraint}")
        }
      end

      # Now build the prefix of this query
      prefix = "SELECT #{fields} FROM #{tables}"
      if(avp and self.class::AVP_TABLES != nil)
        ids = ["id", "id", "id", "id", "id"]
        if(self.class::AVP_IDS.nil?)
          ids = [BRL::Genboree::DBUtil.makeSingularTableName(self.class::PRIMARY_TABLE) + "_id", 
            BRL::Genboree::DBUtil.makeSingularTableName(self.class::AVP_TABLES['names']) + "_id", "id",
            BRL::Genboree::DBUtil.makeSingularTableName(self.class::AVP_TABLES['values']) + "_id", "id"]
        else
          ids = self.class::AVP_IDS
        end
        prefix += ", #{self.class::AVP_TABLES['names']} a, #{self.class::AVP_TABLES['values']} v, " +
          "#{self.class::AVP_TABLES['join']} a2v WHERE p.#{self.class::PRIMARY_ID} = a2v.#{ids[0]} AND " +
          "a2v.#{ids[1]} = a.#{ids[2]} AND a2v.#{ids[3]} = v.#{ids[4]} AND "
      elsif(avp and self.class::AVP_TABLES == nil)
        # TODO - throw an error
        $stderr.puts("BRL::Genboree::REST::Data::Builders::Builder.buildSql(): One or more attributes are not part of CORE_FIELDS and no AVP_TABLES (Badly formed query)")
      else
        prefix += " WHERE "
      end

      # Build our sql statement by processing the JSON recursively
      sql = "#{prefix} #{queryToSql(query)}"
      sql += " AND #{constraints}" unless(constraints.nil?)
      $stderr.puts("Transformed Query to SQL: #{query.inspect} => #{sql.inspect}")
      return sql
    end

    # This method is one of the core methods of the Query Engine framework.  It
    # is used to build a very specific +Hash+ that can be used by the rest of
    # the framework.  This +Hash+ is compatible with the +Hash+ used by the
    # +GenboreeDBHelper+ module and the methods defined therein, in order to
    # allow us to use some of these methods in the +TrackBuilder+ class.
    # [+query+] A String containing the JSON version of the Boolean Query.
    # [+dbu+] A valid +DBUtil+ object
    # [+refSeqId+] The ID of the refseq which we will operate on when applying
    #   this query.  This doesn't necessarily have to be where the query lives,
    #   since the query JSON is supplied as an argument to this method.
    # [+userId+] userId of the User requesting query results.  This is necessary
    #   for checking the permissions of the user, ensuring that the applyQuery
    #   method only returns entities the user has access to.
    # [+detailed+] A boolean to determine which method to use to process your query
    #   results; a value of "false" will use the buildTextEntites method to prepare
    #   the query results, while "true" will use the buildDataEntities method.
    # [+format+] The file format for the return type.  This is ignored by most
    #   +Builder+ subclasses, but those subclasses that respond with data stream
    #   for chunking data will need to know the format ahead of time.
    # [+returns+]
    #   Hash of database rows keyed by "name"; to support subsequent queries
    #   on the object represented by the row, the 'dbNames' key will have an
    #   array of struct objects that specify each related database (dbRec.dbName)
    #   where the object NAME can be found and the datbase id (dbRec.ftypid) within
    #   the respective database. The first dbRec struct will be the user database
    #   so it can override content in the template/other databases.
    #   NOTE: For compatibility with previous code in some of the helper classes
    #     written specifically for tracks, the object id is called +dbRec.ftypeid+
    #     as opposed to a more logical name.  This does not mean that the data
    #     returned by this method always represents track data!
    #   NOTE: (TAC) The first dbRec struct might not be the userDb if the ftype
    #     record doesn't exist in the userDb yet.

    def applyQuery(query, dbu, refSeqId, userId, detailed=false, format=nil)
      # Create the SQL in a separate method so that subclasses can override
      # this method and add additional constraints if necessary
      sql = buildSql(JSON.parse(query))

      # Get all dbs
      allDbs = dbu.selectDBNamesByRefSeqID(refSeqId)
      # Get the userDB refseq DB name (this has priority over shared/template dbs)
      #userDbName = dbu.selectDBNameByRefSeqID(refSeqId) # Can't we do this without a second SQL query? YES - SGD
      #userDbName = userDbName.first['databaseName'] # array of DBI::Rows returned, get actual name String
      userDbName = allDbs.first["databaseName"]  # Fallback value
      allDbs.each{ |uploadRow| userDbName = uploadRow["databaseName"] if(uploadRow['refSeqId'] == refSeqId) }
      allDbs.sort! { |left, right| # make sure -user- database is at first of list
        if(left['databaseName'] == userDbName)
          retVal = -1
        elsif(right['databaseName'] == userDbName)
          retVal = 1
        else
          retVal = left['databaseName'] <=> right['databaseName']
        end
      }

      # Process each DB one at a time
      rows = {}
      allDbs.each{ |uploadRow| 
        dbName = uploadRow["databaseName"]
        dbu.setNewDataDb(dbName)

        # Query the database for a result
        # NOTE: This could be very expensive if we have created an expensive SQL
        #   statement especially for database tables with large numbers of AVPs
        dbRows = dbu.queryResults(sql)

        # Process the results
        unless(dbRows.nil?)
          dbRows.each{ |dbRow|
            # Make the DbRec to keep track of this row
            dbRec = DbRec.new(dbName, dbRow[self.class::PRIMARY_ID], (dbName == userDbName) ? :userDb : :sharedDb)

            # Assume all rows are keyed by "getName()"
            name = getName(dbRow)
            unless(rows.key?(name))
              # We've never seen this row, make a new one
              rowHash = dbRow.to_h()
              rowHash['dbNames'] = [ dbRec ]
              rows[name] = rowHash
            else
              # Already have this row, just append the DbRec record to the dbNames array
              rows[name]['dbNames'] << dbRec
            end
          }
        end

        # Cleanup
        dbRows.clear() unless (dbRows.nil?)
      }
      
      #$stderr.puts("Execution of query returned #{rows.inspect}")
      if(rows.nil?)
        # FIXME
        raise "Database Error!!"
      elsif(rows.empty?)
        return BRL::Genboree::REST::Data::EntityList.new(false)
      else
        rows = filterByPermissions(dbu, rows, userId)
        return buildTextEntities(dbu, rows, @refBase) if(detailed == false)
        return buildDataEntities(dbu, rows, @refBase) if(detailed == true)
      end
    end

    #------
    # The following methods are simply signatures, concrete implementations of
    # these should be defined in any subclass that are created.
    #------

    # This method is intended to supply permissions and security restrictions
    # on the Boolean Query system.  Since the SQL translated by the engine does
    # not know how to handle permissions for any generic object, the subclasses
    # must provide this functionality in this list.  The dbRows object should
    # simply be pruned by this method and any rows that the user identified by
    # the supplied +userId+ does not have access to should be removed.  This
    # method can operate on the +dbRows+ +Hash+ directly since it is passed by
    # reference, but should also return the resulting +Hash+
    # [+dbu+] A valid +DBUtil+ object
    # [+dbRows+] The special +Hash+ returned from a call to +applyQuery()+
    # [+userId+] The userId to check permissions for.
    # [+returns+] The filtered +Hash+ (from +dbRows+)
    def filterByPermissions(dbu, dbRows, userId)
      return dbRows
    end

    # This method will contain the code to build the appropriate +TextEntityList+
    # when detailed=false.
    # [+dbu+] A valid +DBUtil+ object
    # [+dbRows+] The special +Hash+ returned from a call to +applyQuery()+
    # [+refBase+] The base for the refs +Hash+ when building +DataEntities+
    # [+returns+] A +TextEntityList+ with refs hashs (for further details)
    def buildTextEntities(dbu, dbRows, refBase)
      return TextEntityList.new(false)
    end

    # This method will contain the code to build the appropriate REST
    # +DataEntityList+ object normally returned by the resource list that is
    # we are operating on.  This method is only used if detailed=true for the
    # original REST GET operation.
    # [+dbu+] A valid +DBUtil+ object
    # [+dbRows+] The special +Hash+ returned from a call to +applyQuery()+
    # [+refBase+] The base for the refs +Hash+ when building +DataEntities+
    # [+returns+] A subclass of +DataEntityList+ (in most cases, LFF in some)
    def buildDataEntities(dbu, dbRows, refBase)
      return EntityList.new(false)
    end

    # This method is a simple method to assign a name to a database row that
    # was returned from the execution of the SQL statement.  In most cases,
    # this is simply a field in the database (sometimes name, sometimes
    # something else).  But in certain special cases, something other than a
    # name can be used.
    # NOTE: this name can be used to implement data grouping over the user and
    # template databases, like in the case of Ftypes (tracks).
    # [+dbRow+] A DBI::Row object obtained from the execution of the SQL
    #   returned from the +buildSQL()+ method.
    # [+return+] The name assigned to this row
    def getName(dbRow)
      # Concrete subclass implementation needed
      return dbRow['name']
    end

    # This method should be overridden to provide the regexp pattern that will
    # identify what URL's this builder can handle (just like
    # +GenboreeResource#pattern()+ ).  Usually, this call is simply passed on to
    # the +GenboreeResource+ subclass that this +Builder+ subclass is associated
    # with.
    def self.pattern()
      return nil
    end

    # This method is necessary only for those subclasses that cannot return a
    # subclass of +AbstractEntityList+.  For those subclasses (implementing
    # chunked String responses) the content type must be explicitly mentioned
    # or the response will potentially have the wrong MIME type.  Any
    # subclasses that return an +EntityList+ do not have to override this
    # method.
    def content_type()
      return "text/plain"
    end
  end # class Builder
end # module Builders
end ; end ; end ; end # module BRL ; Genboree ; REST ; Data
