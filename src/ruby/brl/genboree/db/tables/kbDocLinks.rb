require 'brl/genboree/dbUtil'

# ------------------------------------------------------------------
# RUN RELATED TABLES - DBUtil Extension Methods for dealing with Run-related tables
# ------------------------------------------------------------------
module BRL ; module Genboree
  class DBUtil


    # the query size should not exceed the max allowed packet
    # keeping a safe target of 64MB
    MAX_REC_SIZE = 200_000
    # ----------------------------------------------------------------
    # Misc/Utility
    # ----------------------------------------------------------------

    # Get the 'kbDocLinks' table name for a specific collection.
    # @param [String] collName The name of the collection.
    # @return [String] The name of table (may or may not exist yet).
    def kbDocLinks_tableName(collName)
      collName = collName.gsub(".", "")
      return '{collName}_kbDocLinks'.gsub(/\{collName\}/, mysql2gsubSafeEsc(collName.makeSafeStr))
    end

    # ----------------------------------------------------------------
    # Create table.
    # ----------------------------------------------------------------

    KBDOCLINKS_CREATE_TABLE_FOR_COLL_SQL = <<-EOS
      CREATE TABLE IF NOT EXISTS {tableName}(
      id int(10) unsigned NOT NULL AUTO_INCREMENT,
      srcDocId text NOT NULL,
      srcProp varchar(1024) NOT NULL,
      tgtColl varchar(1024) NOT NULL,
      tgtDocId text NOT NULL,
      srcDocIdSHA1 char(40) NOT NULL,
      srcPropSHA1 char(40) NOT NULL,
      tgtCollSHA1 char(40) NOT NULL,
      tgtDocIdSHA1 char(40) NOT NULL,
      PRIMARY KEY (id),
      UNIQUE KEY (srcDocIdSHA1, srcPropSHA1, tgtDocIdSHA1),
      KEY (srcDocIdSHA1, tgtCollSHA1),
      KEY (tgtDocIdSHA1, tgtCollSHA1, srcPropSHA1)
    ) ENGINE=MyISAM DEFAULT CHARSET=latin1
    EOS

    # Provide the SQL for creating a 'kbDocLinks' table to back a specific collection.
    # @note @srcProp@ will contain the full MODEL prop path in @collName@.
    # @note The unique key means that even if some item list property is repeated
    #   with the SAME target doc reference, there is only 1 record for that item list
    #   property which links the source doc to the target doc via that item list property.
    #   This index is also used to quickly find the target doc indicated by a given
    #   source doc and property path.
    # @note A related key allows us to quickly find records indicating ALL links from
    #   the source doc to target docs in a specific target collection, regardless of
    #   source property. "Just get me all the target docs ids [where target collection is X]"
    # @note The target oriented is most useful for handling doc deletions: by finding
    #   records which point to the deleted document, we find the set of now "invalid"
    #   records (or invalid links TO the deleted document)
    # @param [String] collName The name of the collection needing a kbDocLinks table to back it.
    # @return [String] The create table sql.
    def kbDocLinks_createTableSql(collName)
      sql = KBDOCLINKS_CREATE_TABLE_FOR_COLL_SQL.gsub(/\{tableName\}/, kbDocLinks_tableName(collName))
      return sql
    end

    # Create the 'kbDocLinks' table needed to back a specific collection.
    # @param [String] collName The name of the collection needing a kbDocLinks table to back it.
    # @return [Fixnum, nil] retVal is stmt.rows-row processed count of the executed statement or nil if no such exist, 0 or nil here
    def kbDocLinks_createTable(collName)
      retVal = sql = nil
      begin
        sql = kbDocLinks_createTableSql(collName)
        connectToDataDb()                                     # Lazy connect to data database
        stmt = @dataDbh.prepare(sql)
        stmt.execute()
        retVal = stmt.rows
      rescue => @err
        DBUtil.logDbError("#{File.basename(__FILE__)} => #{__method__}(): ", @err, sql)
      ensure
        stmt.finish() unless(stmt.nil?)
      end
      return retVal
    end

    # ----------------------------------------------------------------
    # Selection
    # ----------------------------------------------------------------

    # Convenience method. Select kbDocLinks records using the source doc id
    #   AND a set of srcProps of interest. Finds records using FROM SOURCE info.
    # @param [String] collName The source collection name (used to determine the table to query)
    # @param [String] srcDocId The source doc id whose link records for a specific property to return.
    # @param [Array<String>] srcProps The source prop paths of interest.
    # @return [Array<Array>] The result set table, possibly empty.
    def selectKbDocLinksBySrcDocIdAndSrcProp(collName, srcDocId, srcProp)
      return selectKbDocLinksBySrcDocId(collName, srcDocId, srcProp)
    end

    # Convenience method. Select kbDocLinks records using the source doc id
    #   AND the a specific target collection of interest. Finds records using FROM SOURCE info.
    # @param [String] collName The source collection name (used to determine the table to query)
    # @param [String] srcDocId The source doc id whose link records for a specific property to return.
    # @param [String] tgtColl The target collection  of interest.
    # @return [Array<Array>] The result set table, possibly empty.
    def selectKbDocLinksBySrcDocIdAndTgtColl(collName, srcDocId, tgtColl)
      return selectKbDocLinksBySrcDocId(collName, srcDocId, nil, tgtColl)
    end

    # Select kbDocLinks record using the source doc id, optionally restricted by a
    #   specific srcProp and/or tgtColl. Finds records using FROM SOURCE info.
    # @param [String] collName The source collection name (used to determine the table to query)
    # @param [String] srcDocId The source doc id whose link records for a specific property to return.
    # @param [Array<String>] srcProps Optional. The source prop paths of interest.
    # @param [String] tgtColl Optional. The target collection  of interest.
    # @return [Array<Array>] The result set table, possibly empty.
    def selectKbDocLinksBySrcDocId(collName, srcDocId, srcProps=nil, tgtColl=nil)
      return selectKbDocLinksBySrcDocIds(collName, [ srcDocId ], srcProps, tgtColl)
    end

    
    KBDOCLINKS_SELECT_BY_SRC_DOC_IDS = "select srcDocId, srcProp, tgtColl, tgtDocId from {tableName} where srcDocIdSHA1 in {srcDocIdsSet}"
    # Select kbDocLinks records using a list of source doc ids of interest, optionally restricted by a
    #   specific srcProp and/or tgtColl. Finds records using FROM SOURCE info.
    # @param [String] collName The source collection name (used to determine the table to query)
    # @param [Array<String>] srcDocIds The source doc ids whose link records for a specific property to return.
    # @param [Array<String>] srcProps Optional. The source prop paths of interest.
    # @param [String] tgtColl Optional. The target collection  of interest.
    # @return [Array<Array>] The result set table, possibly empty.
    def selectKbDocLinksBySrcDocIds(collName, srcDocIds, srcProps=nil, tgtColl=nil)
      retVal = nil
      tableName = kbDocLinks_tableName(collName)
      sql = KBDOCLINKS_SELECT_BY_SRC_DOC_IDS.gsub(/\{tableName\}/, tableName)
      
      unless(srcDocIds.nil?)
        srcDocIds = [ srcDocIds ] unless(srcDocIds.is_a?(Array))
        srcDocIdsSet = DBUtil.makeMysql2SetStr(srcDocIds, {:sha1Cols => true})
        sql.gsub!(/\{srcDocIdsSet\}/, srcDocIdsSet)
        # Append additional conditions to the query, if any
        if(srcProps)
          srcProps = [ srcProps ] unless(srcProps.is_a?(Array))
          sql << " and srcPropSHA1 in "
          sql << DBUtil.makeMysql2SetStr(srcProps, {:sha1Cols => true})
        end
        if(tgtColl)
          tgtColl = [ tgtColl ] unless(tgtColl.is_a?(Array))
          sql << " and tgtCollSHA1 in "
          sql << DBUtil.makeMysql2SetStr(tgtColl, {:sha1Cols => true})
        end
         #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "Select SQL: #{sql.inspect}")
        begin
          client = getMysql2Client(:userDB)
          resultSet = client.query(sql, :cast_booleans => true)
          retVal = resultSet.entries
        rescue => err
           DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", err, sql)
        ensure
          client.close rescue nil
        end
      end
      return retVal

    end

    # Select kbDocLinks records using a tgtDocId AND tgtColl (required for tgtDocId to make sense)
    #   and/or filtered for those matching a specific source prop path. Finds records using TO TARGET BY SOURCE info.
    # @param [String] collName The source collection name (used to determine the table to query)
    # @param [String] tgtDocId The source doc id whose link records for a specific property to return.
    # @param [String] tgtColl The target collection name (used to determine the table to query)
    # @param [Array<String>] srcProps Optional. The source prop paths of interest.
    # @return [Array<Array>] The result set table, possibly empty.
    def selectKbDocLinksByTgtDocIdAndColl(collName, tgtDocId, tgtColl, srcProps=nil)
      return selectKbDocLinksByTgtDocIdsAndColl(collName, [ tgtDocId ], tgtColl, srcProps)
    end

    KBDOCLINKS_SELECT_BY_TGT_DOC_IDS_AND_COLL = "select srcDocId, srcProp, tgtColl, tgtDocId from {tableName} where tgtDocIdSHA1 in {tgtDocIdSet} and tgtCollSHA1 in {tgtCollSet}"
    # Select kbDocLinks records using a set of relevant tgtDocIds AND tgtColl (required for tgtDocIds to make sense)
    #   and/or filtered for those matching a specific source prop path. Finds records using TO TARGET BY SOURCE info.
    # @param [String] collName The source collection name (used to determine the table to query)
    # @param [Array<String>] tgtDocIds List of target doc ids whose link records for a specific property to return.
    # @param [Array<String>, String] tgtColl an array or a string of the name of the target colection
    # @param [Array<String>] srcProps Optional. The source prop paths of interest.
    # @return [Array<Array>] The result set table, possibly empty.
    def selectKbDocLinksByTgtDocIdsAndColl(collName, tgtDocIds, tgtColl, srcProps=nil)
      retVal = nil
      tableName = kbDocLinks_tableName(collName)
      sql =  KBDOCLINKS_SELECT_BY_TGT_DOC_IDS_AND_COLL.gsub(/\{tableName\}/, tableName)
      unless(tgtDocIds.nil? and tgtColl.nil)
        tgtDocIds = [ tgtDocIds ] unless(tgtDocIds.is_a?(Array))
        tgtDocIdSet = DBUtil.makeMysql2SetStr(tgtDocIds, {:sha1Cols => true})
        sql.gsub!(/\{tgtDocIdSet\}/, tgtDocIdSet)
        tgtColl = [ tgtColl ] unless(tgtColl.is_a?(Array))
        tgtCollSet = DBUtil.makeMysql2SetStr(tgtColl, {:sha1Cols => true})
        sql.gsub!(/\{tgtCollSet\}/, tgtCollSet)

        #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "Select SQL: #{sql.inspect}")
        # optional condition
        if(srcProps)
          srcProps = [ srcProps ] unless(srcProps.is_a?(Array))
          sql << " and srcPropSHA1 in "
          sql << DBUtil.makeMysql2SetStr(srcProps, {:sha1Cols => true})
        end
         #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "Select SQL: #{sql.inspect}")
        begin
          client = getMysql2Client(:userDB)
          resultSet = client.query(sql, :cast_booleans => true)
          retVal = resultSet.entries
        rescue => err
           DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", err, sql)
        ensure
          client.close rescue nil
        end
      end
      return retVal
    end



    # ----------------------------------------------------------------
    # Upsert (combined insert & update using insert-with-on-duplicate-key-update)
    # ----------------------------------------------------------------

    # Upsert (insert or update) a src->tgt link record into a collection's 'kbDocLinks' table.
    # @param [String] collName The collection.
    # @param [String] srcDocId The id of the doc in collection which has the link.
    # @param [String] srcProp The prop path in the source doc which has the link.
    # @param [String] tgtColl The collection where the target doc lives. Supposedly.
    # @param [String] tgtDocId The id of the target doc in the target collection
    # @return [Fixnum] The number of rows inserted
    def upsertKbDocLinkForColl(collName, srcDocId, srcProp, tgtColl, tgtDocId)
      return upsertKbDocLinksForColl(collName, [ [ srcDocId, srcProp, tgtColl, tgtDocId ] ], 8, true, true )
    end

    # Upsert multiple src->tgt link records into a collections 'kbDocLinks' table.
    # @param [String] collName The collection.
    # @param [Array, Array<Array>] data The record data to insert. Must a 2-D array of
    #        arrays/rows . The order of fields must be: srcDocId, srcProp, tgtColl, tgtDocId
    #        The last four columns are sha1 values of the first four resp, so can provide 
    #        just the first four columns - [srcDocId, srcProp, tgtColl, tgtDocId] or the
    #        full set of columns - [srcDocId, srcProp, tgtColl, tgtDocId, srcDocId, srcProp, tgtColl, tgtDocId]
#        However, if only the first fourd cols are provided the colsDuplicate must be set to true, so that
#        the duplication of the cols are done. 
    # @param [Fixnum] numCols The number of cols per row.
    # @param [Boolean] reserveId Should the method reserve the first column in each record for an autoincrement id?
    # @param [Boolean] colsDuplicate Should the values in each array of @data@ be doubled 
    # @note Do not keep reserveId to true if "nil" is already present as the first element 
    # @return [Fixnum] The number of rows inserted.
    def upsertKbDocLinksForColl(collName, data, numCols=4, reserveId=true, colsDuplicate=true)
      retVal = 0
      sql = nil
      tableName = kbDocLinks_tableName(collName)
      dupKeyUpdateCol = [ "srcDocId", "srcProp", "tgtColl", "tgtDocId"]
      # Duplicate the values in each array
      if(data.is_a?(Array))
        if(colsDuplicate)
          # duplicate the cols for the sha1 cols 5-8
          if(reserveId)
            data.map!{ |dataList| dataList*2 }
            numCols = 8
          else
            # first value is nil
            data.map! {|dataList| [dataList.first, dataList[1..(dataList.size)]*2].flatten}
            numCols = 9
          end
        end
        if(reserveId)

          retVal = upsertRecords(:userDB, tableName, data, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", numCols, reserveId, dupKeyUpdateCol, {:sha1Cols => [4, 5, 6, 7]})
        else
          retVal = upsertRecords(:userDB, tableName, data, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", numCols, reserveId, dupKeyUpdateCol, {:sha1Cols => [5, 6, 7, 8]})
        end
      end
      return retVal
    end

    KBDOCLINKS_UPSERT_FOR_COLL_SQL = "insert into {tableName} values"
    # Inserts one or more records to a table using "insert values" type SQL statement
    #   directly without prepare-execute approach and without using bind slots.
    # This will work for tables in main genboree, database, user database, or an other database.
    # You must have properly set the right database handle.
    # The data must be an array of arrays (2-D, mimicing the rows and column).
    # @param [Symbol] tableType   A flag indicating which database handle to use for executing the query.
    #                 One of these +Symbols+:
    #                 :userDB, :mainDB, :otherDB
    # @param [String] tableName  Name of the table to select from.
    # @param [Array<Array>] data Array of all data values used to construct the records; do not provide
    #                 "null" for autoincrement id column if you have reserveId=true set...this
    #                 method will add them. Must be array of arrays (2-D, mimicing the rows and column); regardless,
    #                 this method will flatten() it before using it.
    # @param [boolean] reserveId Should the method reserve the first column in each record for an autoincrement
    #                 id? Most often true.
    # @param [String] errMsg  Prefix to use when an error is raised and logged vis logDbError.
    # @param [Fixnum] numBindVarsPerRecord  The number of column fields per record.
    # @param [Boolean, Array] dupKeyUpdateCol specifies the column name if using duplicate key update inserts
    # @param [Hash] opts optional arguments if any, usually used by the method makeMysql2ValuesStr
    # @return [Fixnum] The number of rows inserted
    def upsertRecords(tableType, tableName, data, errMsg, numBindVarsPerValue, reserveId, dupKeyUpdateCol=false, opts={})
      sql = nil
      retVal = 0
      0.step(data.size, MAX_REC_SIZE){|ii|
        sql = KBDOCLINKS_UPSERT_FOR_COLL_SQL.gsub(/\{tableName\}/, tableName)
        inputData = data[ii..(ii + MAX_REC_SIZE) - 1]
        if(inputData.size > 0)
          dataValues = DBUtil.makeMysql2ValuesStr(inputData.flatten, numBindVarsPerValue, reserveId, opts)
          sql << dataValues
          if(dupKeyUpdateCol)
            dupSql = " on duplicate key update "
            if(dupKeyUpdateCol.is_a?(Array))
              lastIdex = dupKeyUpdateCol.size - 1
              dupKeyUpdateCol.size.times { |ii|
                if(ii != lastIdex)
                  dupSql << " #{dupKeyUpdateCol[ii]} = VALUES(#{dupKeyUpdateCol[ii]}), "
                else
                  dupSql << " #{dupKeyUpdateCol[ii]} = VALUES(#{dupKeyUpdateCol[ii]}) "
                end
              }
            else
              dupSql << " #{dupKeyUpdateCol} = VALUES(#{dupKeyUpdateCol}) "
            end
          sql << dupSql
          end
          #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "KBDOCLINKS_UPSERT_FOR_COLL_SQL SIZE----->  : #{sql.size}")
          begin
            client = getMysql2Client(:userDB)
            resultSet = client.query(sql, :cast_booleans => true)
            retVal = client.affected_rows
          rescue => err
            DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", err, sql)
            raise err
            break
          ensure
            client.close
          end
        end
       }
      return retVal
    end

    # Upsert raw kbDocLinks table rows. Presumably it was easier to accumulate the rows
    #   and/or there are a mix of kbDocs and/or property combinations involved so one of the
    #   pattern/set based methods above won't work.
    # @param [String] collName The collection.
    # @param [Array<Array>] rows The raw rows to upsert. Ideally 5 column with nil in the first column.
    #   However, if only 4 columns a nil first column (id) will be added for you. Rows with other than
    #   4 or 5 columns are not supported.
    # @return [Fixnum] The number of rows upserted.
    def upsertKbDocLinksRawRows(collName, rows)
      data = []
      # Make sure we've got a nil in the first (id) column.
      fixedRows = rows.map { |row|
        raise ArgumentError, "ERROR: This row has only #{row.size} columns. Must be 4 (data cols only) or 5 (row id + data cols) columns:  #{row.inspect}" unless(row.size == 4 or row.size == 5)
        if(row.size == 4)
          fixedRow = row.unshift(nil)
        else # with a nil
          fixedRow = row
        end
        data << fixedRow
      }
      upsertKbDocLinksForColl(collName, data, numCols=5, false, true)
      # @todo Implement.
    end
    # ----------------------------------------------------------------
    # Deletion
    # ----------------------------------------------------------------

    # Convenience method. Delete all the 'kbDocLinks' record for a specific docId in given collection,
    #   optionally restricted to records for a certain source property and/or target collection.
    # @param [String] collName The collection name.
    # @param [String] srcDocId The doc id of the document in @collName@ for which to delete all the
    #   kbDocLinks records.
    # @param [String] srcProp Optional. The prop path in the source doc which has the link.
    # @param [String] tgtColl Optional. The collection where the target doc lives. Supposedly.
    # @return [Fixnum] The number of deleted records.
    def deleteKbDocLinksBySrcDocId(collName, srcDocId, srcProp=nil, tgtColl=nil)
      return deleteKbDocLinksBySrcDocIds(collName, [ srcDocId ], srcProp, tgtColl)
    end

    KBDOCLINKS_DELETE_BY_SRC_DOC_IDS = "delete from {tableName} where srcDocIdSHA1 in {srcDocIdsSet} "
    # Delete all the 'kbDocLinks' record for the provided docIds in given collection,
    #   optionally restricted to records for a certain source property and/or target collection..
    # @param [String] collName The collection name.
    # @param [Array<String>] srcDocId The doc ids of the documents in @collName@ for which to delete all the
    #   kbDocLinks records.
    # @param [String] srcProp Optional. The prop path in the source doc which has the link.
    # @param [String] tgtColl Optional. The collection where the target doc lives. Supposedly.
    # @return [Fixnum] The number of deleted records.
    def deleteKbDocLinksBySrcDocIds(collName, srcDocIds, srcProp=nil, tgtColl=nil)
      retVal = nil
      tableName = kbDocLinks_tableName(collName)
      sql = KBDOCLINKS_DELETE_BY_SRC_DOC_IDS.gsub(/\{tableName\}/, tableName)
      unless(srcDocIds.nil?)
        srcDocIds = [ srcDocIds ] unless(srcDocIds.is_a?(Array))
        srcDocIdsSet = DBUtil.makeMysql2SetStr(srcDocIds, {:sha1Cols => true})
        sql.gsub!(/\{srcDocIdsSet\}/, srcDocIdsSet)
       
        if(srcProp)
          srcProp = [ srcProp ] unless(srcProp.is_a?(Array))
          sql << " and srcPropSHA1 in "
          sql << DBUtil.makeMysql2SetStr(srcProp, {:sha1Cols => true})
        end
        if(tgtColl)
          tgtColl = [ tgtColl ] unless(tgtColl.is_a?(Array))
          sql << " and tgtCollSHA1 in "
          sql << DBUtil.makeMysql2SetStr(tgtColl, {:sha1Cols => true})
        end
         #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "DELETE SQL -----> KBDOCLINKS_DELETE_BY_SRC_DOC_IDS: #{sql.inspect}")
        begin
          client = getMysql2Client(:userDB)
          resultSet = client.query(sql, :cast_booleans => true)
          retVal = client.affected_rows
        rescue => err
           DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", err, sql)
        ensure
          client.close rescue nil
        end
      end
      return retVal
    end



    KBDOCLINKS_DELETE_BY_SRC_INFO_PAIRS = "delete from {tableName} where"
    # Delete all the 'kbDocLinks' records by pairs of srcDocId and srcProp. Useful when an upsert operation
    #   discovers that some srcProps don't have [or no longer have] tgtDocIds.
    # @param [String] collName The collection name.
    # @param [Array<Array<String,String>>] srcInfoPairs. An array of tuples. The first value in the tuple is
    #   a srcDocId while the second value in the tuple is a srcProp path. The tuple thus specifies a record to be
    #   removed. Different srcDocIds in the pairs list may be removing records for different srcProps. For example:
    #   Doc A is no longer linked to a target via some.prop.path.1 ; Doc B is no longer linked to a target via
    #   some.prop.path 1 and ALSO no longer linked to a target via via some.other.path.2
    # @return [Fixnum] The number of deleted records.
    def deleteKbDocLinksBySrcInfoPairs(collName, srcInfoPairs)
      retVal = nil
      # Info pairs of srcDocIdSHA1=sha1({srcDocId}) AND srcPropSHA1=sha1('{srcProp}')
      # Unescaped srcDocId and srcProp as the sha1 values of unescaped variables are needed here
      tableName = kbDocLinks_tableName(collName)
      sql = KBDOCLINKS_DELETE_BY_SRC_INFO_PAIRS.gsub(/\{tableName\}/, tableName)
      cond = " (srcDocIdSHA1=sha1('{srcDocId}') and srcPropSHA1=sha1('{srcProp}')) "
      if(srcInfoPairs.is_a?(Array) and !srcInfoPairs.empty?)
        srcInfoPairs.each_with_index {|pair, index|
        raise ArgumentError, "ERROR: Info pair must be an an array of two string elements [{srcDocId}, {srcProp}]. But found #{pair.class} with #{pair.nil? ? "no" : pair.size.inspect} elements" unless(pair.is_a?(Array) and pair.size == 2)
        tmp = cond.gsub(/\{srcDocId\}/, pair.first.strip)
        sql << tmp.gsub(/\{srcProp\}/, pair.last.strip) 
        sql << "or" unless(index == srcInfoPairs.size-1)         
        }
        #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "DELETE SQL -----> KBDOCLINKS_DELETE_BY_SRC_INFO_PAIRS: #{sql.inspect}")
        # make the query
        begin
          client = getMysql2Client(:userDB)
          resultSet = client.query(sql, :cast_booleans => true)
          retVal = client.affected_rows
        rescue => err
          DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", err, sql)
        ensure
          client.close rescue nil
        end
      end
      return retVal
    end


    KBDOCLINKS_DELETE_BY_SRC_PROP_AND_TGT_COLL = "delete from {tableName} where srcPropSHA1 in {srcPropSet} and tgtCollSHA1 in {tgtCollSet}"
    # a  source property no longer exists in a collection - delete all the kbDocLinks for that
    #   source prop and target collection
    def deleteKbDocLinksBySrcPropAndTgtColl(collName, srcProp, tgtColl)
      retVal = nil
      tableName = kbDocLinks_tableName(collName)
      sql = KBDOCLINKS_DELETE_BY_SRC_PROP_AND_TGT_COLL.gsub(/\{tableName\}/, tableName)
      unless(srcProp.nil? and tgtColl.nil?)
        srcProp = [ srcProp ] unless(srcProp.is_a?(Array))
        srcPropSet = DBUtil.makeMysql2SetStr(srcProp, {:sha1Cols => true})
        sql.gsub!(/\{srcPropSet\}/, srcPropSet)

        tgtColl = [ tgtColl ] unless(tgtColl.is_a?(Array))
        tgtCollSet = DBUtil.makeMysql2SetStr(tgtColl, {:sha1Cols => true})
        sql.gsub!(/\{tgtCollSet\}/, tgtCollSet)

         #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "DELETE SQL ->>>  KBDOCLINKS_DELETE_BY_SRC_PROP_AND_TGT_COLL: #{sql.inspect}")
        begin
          client = getMysql2Client(:userDB)
          resultSet = client.query(sql, :cast_booleans => true)
          retVal = client.affected_rows
        rescue => err
           DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", err, sql)
        ensure
          client.close rescue nil
        end
      end
      return retVal
    end


    KBDOCLINKS_DELETE_BY_TGT_DOC_AND_TGT_COLL = "delete from {tableName} where tgtDocIdSHA1 in {tgtDocIdSet} and tgtCollSHA1 in {tgtCollSet}"
    def deleteKbDocLinksByTgtDocIdsAndTgtColl(collName, tgtDocId, tgtColl)
      retVal = nil
      tableName = kbDocLinks_tableName(collName)
      sql = KBDOCLINKS_DELETE_BY_TGT_DOC_AND_TGT_COLL.gsub(/\{tableName\}/, tableName)
      unless(tgtDocId.nil? and tgtColl.nil?)
        tgtDocId = [ tgtDocId ] unless(tgtDocId.is_a?(Array))
        tgtDocIdSet = DBUtil.makeMysql2SetStr(tgtDocId, {:sha1Cols => true})
        sql.gsub!(/\{tgtDocIdSet\}/, tgtDocIdSet)

        tgtColl = [ tgtColl ] unless(tgtColl.is_a?(Array))
        tgtCollSet = DBUtil.makeMysql2SetStr(tgtColl, {:sha1Cols => true})
        sql.gsub!(/\{tgtCollSet\}/, tgtCollSet)

        #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "DELETE SQL ---> KBDOCLINKS_DELETE_BY_TGT_DOC_AND_TGT_COLL: #{sql.inspect}")
        begin
          client = getMysql2Client(:userDB)
          resultSet = client.query(sql, :cast_booleans => true)
          retVal = client.affected_rows
        rescue => err
           DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", err, sql)
        ensure
          client.close rescue nil
        end
      end
      return retVal

    end




  end # class DBUtil
end ; end # module BRL ; module Genboree
