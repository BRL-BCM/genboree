#!/usr/bin/env ruby

# ##############################################################################
# REQUIRED LIBRARIES
# ##############################################################################
require 'brl/util/textFileUtil' # For TextReader/Writer convenience classes
require 'dbi'
require 'brl/db/dbrc'						# For brl/db/DBRC class and database nicities
# ##############################################################################
# Turn on extra warnings and such
#$VERBOSE = (ENV['RUBY_VERBOSE'] == 'true' ? true : (ENV['RUBY_VERBOSE'] == 'false' ? false : nil))

# FOR REF
# ruby -e 'require "dbi"; require "brl/db/dbrc"; dbrc = BRL::DB::DBRC.new("~/.dbrc", "andrewj_ucsc_hg13"); dbh = DBI.connect(dbrc.driver, dbrc.user, dbrc.password);dbh.columns("xenoEst").each{|cc| print cc.name; puts "\t>>#{cc.default}<<\tnullOK? #{cc.nullable}"; };'
#

module BRL ; module DB

	class InsertError < StandardError ; end
	class CreateError < StandardError ; end
	class TableError < StandardError ; end

	class DBTable
		attr_accessor :dbrc, :database, :dbh
		attr_reader :columnInfoArray
		attr_reader :name, :columnInfoArray

		def initialize(tableName, db) # db can be BRL::DB::DBRC or a database handle (DBI::DatabaseHandle)
			@name = tableName
			if(db.kind_of?(BRL::DB::DBRC))
				@dbrc = db
				@dbh = DBI.connect(@dbrc.driver.untaint, @dbrc.user.untaint, @dbrc.password.untaint)
			else # assume db is a DBI::DatabaseHandle
				@dbh = db
			end
			@columnInfoArray = @dbh.columns(@name)
		end

		# Get create table string
		def DBTable.getCreateTableCommand(name, dbh)
			getCreateSql = "SHOW CREATE TABLE #{name}"
			begin
				row = dbh.select_one(getCreateSql)
			end
			return (row.nil?) ? nil : row[1]
		end

		# Insert values into this table
		def insert(values, safeInsert=false, lockTable=false)
			# should we lock the table?
			self.writeLock() if(lockTable)
			insertSql = safeInsert ? "INSERT IGNORE " : "INSERT INTO "
			insertSql << "#{@name} "
			# values hash
			if(values.kind_of?(Hash))
				colNameStr = '('
				valueStr = ''
				values.each {
					|col, val|
					colNameStr << "#{col},"
					valueStr << "#{self.convertValue(val)},"
				}
				colNameStr.chop! # For efficiency, just trim off trailing comma
				valueStr.chop!
				insertSql << colNameStr
				insertSql << ') VALUES ('
				insertSql << valueStr
				insertSql << ')'
			elsif(values.kind_of?(Array))
				unless(values.size == @columnInfoArray.size)
					raise(BRL::DB::InsertError, "\nERROR: when inserting from array of data, all columns musthave a value (array length = # columns)\n")
				end
				insertSql << 'VALUES ('
				values.each {
					|val|
					insertSql << "#{self.convertValue(val)},"
				}
				insertSql.chop!
				insertSql << ')'
			else
				raise(BRL::DB::InsertError, "\nERROR: can't insert a #{values.type} into table #{@name}\n")
			end
			# prep and do the insert
			begin
				status = @dbh.do(insertSql)
			ensure
				# unlock the table (make sure to do this, even if an error occurred)
				self.unlock() if(lockTable)
			end
			return status
		end

		def convertValue(val)
			if(val.nil? or val.kind_of?(String))
				valueStr = @dbh.quote(val)
			elsif(val =~ /NOW\(\)/i)
				valueStr = "#{val}"
			else
				valueStr = "#{val}"
			end
			return valueStr
		end

		def prepInsert(columnNamesArray, safeInsert=false, lockTable=false)
			# should we lock the table?
			self.writeLock() if(lockTable)
			sth = nil
			# prep statement using columnNamesArray
			insertSql = safeInsert ? "INSERT IGNORE " : "INSERT INTO "
			insertSql << "#{@name} (#{columnNamesArray.join(',')}) "
			insertSql << 'VALUES ('
			valueStr = "?," * columnNamesArray.size
			valueStr.chop!
			insertSql << valueStr
			insertSql << ')'
			begin
				# prepare:
				sth = @dbh.prepare(insertSql)
      ensure
				# If something goes wrong, we need to unlock the table NOW
				self.unlock()
			end
			return sth
		end

		def doPrepInsert(columnNamesArray, values, sth, unlock=false)
			begin
				if(values.kind_of?(Array)) # then fine, as long as length agrees with col names array
					unless(columnNamesArray.size == values.size)
						raise(BRL::DB::InsertError, "\nERROR: your array of values has a different length than the array of column names...bug.\n\n")
					end
					# don't have to convert if using binding!
#					convertedValues = []
#					values.each {
#						|val|
#						convertedValues << self.convertValue(val)
#					}
#					sth.execute(*convertedValues)
					sth.execute(*values)
				elsif(values.kind_of?(Hash))
					valueArray = []
					columnNamesArray.each {
						|colName|
						#valueArray << convertValue(values[colName])
						valueArray << values[colName]
					}
					sth.execute(*valueArray)
				else
					raise(BRL::DB::InsertError, "\nERROR: can't do a prepared insert using values from a #{values.type}. Needs to be a kind of Hash or Array.\n\n")
				end
			ensure
				# should we unlock the table when done?
				self.unlock() if(unlock)
			end
		end

		def insertBatch(columnNamesArray, values, lockTable=false)
			begin
				# should we lock the table?
				self.writeLock() if(lockTable)
				# prep statement using columnNamesArray
				insertSql = safeInsert ? "INSERT IGNORE " : "INSERT INTO "
				insertSql << "#{@name} (#{columnNamesArray.join(',')}) "
				insertSql << 'VALUES ('
				valueStr = "?," * columnNamesArray.size
				valueStr.chop!
				insertSql << valueStr
				insertSql << ')'
				# prepare:
				sth = @dbh.prepare(insertSql)
				# insert each record in the value array
				values.each {
					|value|
					if(value.kind_of?(Array)) # This we can do directly
						convertedValues = []
						value.each {
						|val|
						convertedValues << self.convertValue(val)
					}
					sth.execute(*convertedValuee)
					elsif(value.kind_of?(Hash)) # This we need to get out the values in proper order and then execute using that order
						valueArray = []
						columnNamesArray.each {
							|column|
							valueArray << self.convertValue(value[column])
						}
						sth.execute(*valueArray)
					end
				}
			ensure
				self.unlock() if(lockTable)
			end
		end

		def delete(whereString, lockTable=false)
			deleteSql = "DELETE FROM #{@name} WHERE (#{whereString}) "
			self.writeLock() if(lockTable)
			begin
				@dbh.do(deleteSql)
			ensure
				self.unlock() if(lockTable)
			end
		end

    def update(newValuesHash, whereString=nil, lockTable=false)
    	updateSql = "UPDATE #{@name} SET "
    	newValuesHash.each {
    		|col, val|
    		updateSql << "#{col}=#{self.convertValue(val)},"
    	}
    	updateSql.chop! # oops extra , we are lazy, so chop it off
    	unless(whereString.nil?)
    		updateSql << " WHERE #{whereString} "
    	end
    	begin
    		@dbh.do(updateSql)
    	ensure
    		self.unlock() if(lockTable)
    	end
    end

		def select(whatStr, whereString=nil, orderGroupStr=nil, lockTable=false)
			selectSql = "SELECT #{whatStr} FROM #{@name} "
			unless(whereString.nil?)
				selectSql << "WHERE (#{whereString}) "
			end
			unless(orderGroupStr.nil?)
				selectSql << "#{orderGroupStr} "
			end
			sth = nil
			self.writeLock() if(lockTable)
			begin
				sth = dbh.prepare(selectSql)
				sth.execute
			ensure
				self.unlock() if(lockTable)
			end
			return sth
		end

		def select_one(whatStr, whereString=nil, orderGroupStr=nil, lockTable=false)
			selectSql = "SELECT #{whatStr} FROM #{@name} "
			unless(whereString.nil?)
				selectSql << "WHERE (#{whereString})"
			end
			unless(orderGroupStr.nil?)
				selectSql << "#{orderGroupStr} "
			end
			row = nil
			self.writeLock() if(lockTable)
			begin
				row = dbh.select_one(selectSql)
			ensure
				self.unlock() if(lockTable)
			end
			return row
		end

		def select_all(whatStr, whereString=nil, orderGroupStr=nil, lockTable=false)
			selectSql = "SELECT #{whatStr} FROM #{@name} "
			unless(whereString.nil?)
				selectSql << "WHERE (#{whereString})"
			end
			unless(orderGroupStr.nil?)
				selectSql << "#{orderGroupStr} "
			end
			rows = nil
			self.writeLock() if(lockTable)
			begin
				rows = dbh.select_all(selectSql)
			ensure
				self.unlock() if(lockTable)
			end
			return rows
		end

		def writeLock()
			writeLockSql = "LOCK TABLES #{@name} WRITE"
			@dbh.do(writeLockSql)
		end

		def readLock()
			readLock = "LOCK TABLES #{@name} READ"
			@dbh.do(readLockSql)
		end

		def unlock()
			@dbh.do('UNLOCK TABLES')
		end

		def columnNames
			nameArray = []
			@columnInfoArray.each {
				|colInfo|
				nameArray << colInfo.name
			}
			return nameArray
		end

		def getColumnName(columnIdx)
			return @columnInfoArray[ii].name
		end

		def columnTypes
			typeArray = []
			@columnInfoArray.each {
				|colInfo|
				typeArray << colInfo.type_name
			}
			return typeArray
		end

		def getColumnType(column)
			# column could be a number or column name
			if(column.kind_of?(Numeric) or column =~ /^\d+$/)
				@columnInfoArray[column.to_i].type_name
			else # assume a column name
				@columnInfoArray.each {
					|colInfo|
					if(colInfo.name == column)
						return colInfo.type_name
					end
				}
				return nil # not known prolly because doesn't exist in this table
			end
		end

		def columnNullable(column)
			# column could be a number or column name
			if(column.kind_of?(Numeric) or column =~ /^\d+$/)
				@columnInfoArray[column.to_i].nullable?
			else # assume a column name
				@columnInfoArray.each {
					|colInfo|
					if(colInfo.name == column)
						return colInfo.nullable?
					end
				}
				return nil # not known prolly because doesn't exist in this table
			end
		end

		def getColumnInfo(column)
			# column could be a number or column name
			if(column.kind_of?(Numeric) or column =~ /^\d+$/)
				@columnInfoArray[column.to_i]
			else # assume a column name
				@columnInfoArray.each {
					|colInfo|
					if(colInfo.name == column)
						return colInfo
					end
				}
				return nil # not known prolly because doesn't exist in this table
			end
		end

		def columnDefaultValues
			defaultValues = []
			@columnInfoArray.each {
				|colInfo|
				defaultValues << colInfo.default
			}
			return defaultValues
		end

		def getColumnDefaultValue(column)
			# column could be a number or column name
			if(column.kind_of?(Numeric) or column =~ /^\d+$/)
				@columnInfoArray[column.to_i].default
			else # assume a column name
				@columnInfoArray.each {
					|colInfo|
					if(colInfo.name == column)
						return colInfo.default
					end
				}
				return nil # not known prolly because doesn't exist in this table
			end
		end
	end # class dbTable

	class DBRecord < Hash
		attr_accessor :dbh

		def initialize(db)
			if(db.kind_of?(BRL::DB::DBRC))
				@dbh = DBI.connect(dbrc.driver.untaint, dbrc.user.untaint, dbrc.password.untaint)
			else # assume db is a DBI::DatabaseHandle
				@dbh = db
			end
		end

		def [](key, colNames)
			# check if a valid key
			unless(colNames.key?(key))
				raise(BRL::DB::TableError)
			end
			return super(key)
		end

		def []=(key, value, colNames)
			# check if a valid key
			unless(colNames.key?(key))
				raise(BRL::DB::TableError)
			end
			return super(key, value)
		end
	end

end ; end # module brl ; module db
