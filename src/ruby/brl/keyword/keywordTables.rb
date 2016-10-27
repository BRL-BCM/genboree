#!/usr/bin/env ruby
# ##############################################################################
# REQUIRED LIBRARIES
# ##############################################################################
require 'brl/util/textFileUtil' # For TextReader/Writer convenience classes
require 'dbi'
require 'brl/db/dbrc'						# For brl/db/DBRC class and database nicities
require 'brl/db/util'						# For possibly useful table abstraction
# ##############################################################################
# Turn on extra warnings and such
$VERBOSE = true

# FOR REF
# ruby -e 'require "dbi"; require "brl/db/dbrc"; dbrc = BRL::DB::DBRC.new("~/.dbrc", "andrewj_keyword"); dbh = DBI.connect(dbrc.driver, dbrc.user, dbrc.password);dbh.columns("xenoEst").each{cc print cc.name; puts "\t>>#{cc.default}<<\tnullOK? #{cc.nullable}"; };'
#

module BRL ; module Keyword
	# ############################################################################
	# 'keyword' table
	# ############################################################################
	class KeywordDBTable < BRL::DB::DBTable
		@@name = 'keyword'
		def initialize(db)
			super(@@name, db)
		end
	end

	class KeywordDBRecord < BRL::DB::DBRecord
		@@DBTable = nil
		@@colNames = nil

		def initialize(db)
			super(db)
			if(@@DBTable.nil?) then @@DBTable = BRL::Keyword::KeywordDBTable.new(db) end
			if(@@colNames.nil?)
				@@colNames = {}
				colNamesArray = @@DBTable.columnNames()
				colNamesArray.map{ |colName| @@colNames[colName] = '' }
			end
		end

		def [](key)
			begin
				return super(key, @@colNames)
			rescue BRL::DB::TableError
				raise(BRL::DB::TableError, "\nERROR: '#{key}' is not a valid key in table '#{@@DBTable.name}'\n")
			end
		end

		def []=(key, value)
			begin
				return super(key, value, @@colNames)
			rescue BRL::DB::TableError
				raise(BRL::DB::TableError, "\nERROR: '#{key}' is not a valid key in table '#{@@DBTable.name}'\n")
			end
		end
	end # class KeywordDBRecord < BRL::DB::DBRecord

	# ############################################################################
	# 'keyword_keyword' table
	# ############################################################################
	class Keyword_KeywordDBTable < BRL::DB::DBTable
		@@name = 'keyword_keyword'
		def initialize(db)
			super(@@name, db)
		end
	end

	class Keyword_KeywordDBRecord < BRL::DB::DBRecord
		@@DBTable = nil
		@@colNames = nil

		def initialize(db)
			super(db)
			if(@@DBTable.nil?) then @@DBTable = BRL::Keyword::Keyword_KeywordDBTable.new(db) end
			if(@@colNames.nil?)
				@@colNames = {}
				colNamesArray = @@DBTable.columnNames()
				colNamesArray.map{ |colName| @@colNames[colName] = '' }
			end
		end

		def [](key)
			begin
				return super(key, @@colNames)
			rescue BRL::DB::TableError
				raise(BRL::DB::TableError, "\nERROR: '#{key}' is not a valid key in table '#{@@DBTable.name}'\n")
			end
		end

		def []=(key, value)
			begin
				return super(key, value, @@colNames)
			rescue BRL::DB::TableError
				raise(BRL::DB::TableError, "\nERROR: '#{key}' is not a valid key in table '#{@@DBTable.name}'\n")
			end
		end
	end # class Keyword_KeywordDBRecord < BRL::DB::DBRecord

	# ############################################################################
	# 'fdatakeyword' table
	# ############################################################################
	class FdatakeywordDBTable < BRL::DB::DBTable
		@@name = 'fdatakeyword'
		def initialize(db)
			super(@@name, db)
		end
	end

	class FdatakeywordDBRecord < BRL::DB::DBRecord
		@@DBTable = nil
		@@colNames = nil

		def initialize(db)
			super(db)
			if(@@DBTable.nil?) then @@DBTable = BRL::Keyword::FdatakeywordDBTable.new(db) end
			if(@@colNames.nil?)
				@@colNames = {}
				colNamesArray = @@DBTable.columnNames()
				colNamesArray.map{ |colName| @@colNames[colName] = '' }
			end
		end

		def [](key)
			begin
				return super(key, @@colNames)
			rescue BRL::DB::TableError
				raise(BRL::DB::TableError, "\nERROR: '#{key}' is not a valid key in table '#{@@DBTable.name}'\n")
			end
		end

		def []=(key, value)
			begin
				return super(key, value, @@colNames)
			rescue BRL::DB::TableError
				raise(BRL::DB::TableError, "\nERROR: '#{key}' is not a valid key in table '#{@@DBTable.name}'\n")
			end
		end
	end # class FdatakeywordDBRecord < BRL::DB::DBRecord

	# ############################################################################
	# 'fetd' table
	# ############################################################################
	class FdetDBTable < BRL::DB::DBTable
		@@name = 'fdet'
		def initialize(db)
			super(@@name, db)
		end
	end

	class FdetDBRecord < BRL::DB::DBRecord
		@@DBTable = nil
		@@colNames = nil

		def initialize(db)
			super(db)
			if(@@DBTable.nil?) then @@DBTable = BRL::Keyword::FdetDBTable.new(db) end
			if(@@colNames.nil?)
				@@colNames = {}
				colNamesArray = @@DBTable.columnNames()
				colNamesArray.map{ |colName| @@colNames[colName] = '' }
			end
		end

		def [](key)
			begin
				return super(key, @@colNames)
			rescue BRL::DB::TableError
				raise(BRL::DB::TableError, "\nERROR: '#{key}' is not a valid key in table '#{@@DBTable.name}'\n")
			end
		end

		def []=(key, value)
			begin
				return super(key, value, @@colNames)
			rescue BRL::DB::TableError
				raise(BRL::DB::TableError, "\nERROR: '#{key}' is not a valid key in table '#{@@DBTable.name}'\n")
			end
		end
	end # class FetdDBRecord < BRL::DB::DBRecord

	# ############################################################################
	# 'fdatatable' table
	# ############################################################################
	class FdatatocDBTable < BRL::DB::DBTable
		@@name = 'fdatatoc'
		def initialize(db)
			super(@@name, db)
		end
	end

	class FdatatocDBRecord < BRL::DB::DBRecord
		@@DBTable = nil
		@@colNames = nil

		def initialize(db)
			super(db)
			if(@@DBTable.nil?) then @@DBTable = BRL::Keyword::FdatatocDBTable.new(db) end
			if(@@colNames.nil?)
				@@colNames = {}
				colNamesArray = @@DBTable.columnNames()
				colNamesArray.map{ |colName| @@colNames[colName] = '' }
			end
		end

		def [](key)
			begin
				return super(key, @@colNames)
			rescue BRL::DB::TableError
				raise(BRL::DB::TableError, "\nERROR: '#{key}' is not a valid key in table '#{@@DBTable.name}'\n")
			end
		end

		def []=(key, value)
			begin
				return super(key, value, @@colNames)
			rescue BRL::DB::TableError
				raise(BRL::DB::TableError, "\nERROR: '#{key}' is not a valid key in table '#{@@DBTable.name}'\n")
			end
		end
	end # class FdatatableDBRecord < BRL::DB::DBRecord

	# ############################################################################
	# 'fentrypoint' table
	# ############################################################################
	class FentrypointDBTable < BRL::DB::DBTable
		@@name = 'fentrypoint'
		def initialize(db)
			super(@@name, db)
		end
	end

	class FentrypointDBRecord < BRL::DB::DBRecord
		@@DBTable = nil
		@@colNames = nil

		def initialize(db)
			super(db)
			if(@@DBTable.nil?) then @@DBTable = BRL::Keyword::FentrypointDBTable.new(db) end
			if(@@colNames.nil?)
				@@colNames = {}
				colNamesArray = @@DBTable.columnNames()
				colNamesArray.map{ |colName| @@colNames[colName] = '' }
			end
		end

		def [](key)
			begin
				return super(key, @@colNames)
			rescue BRL::DB::TableError
				raise(BRL::DB::TableError, "\nERROR: '#{key}' is not a valid key in table '#{@@DBTable.name}'\n")
			end
		end

		def []=(key, value)
			begin
				return super(key, value, @@colNames)
			rescue BRL::DB::TableError
				raise(BRL::DB::TableError, "\nERROR: '#{key}' is not a valid key in table '#{@@DBTable.name}'\n")
			end
		end
	end # class FentrypointDBRecord < BRL::DB::DBRecord

	# ############################################################################
	# 'ftype' table
	# ############################################################################
	class FtypeDBTable < BRL::DB::DBTable
		@@name = 'ftype'
		def initialize(db)
			super(@@name, db)
		end
	end

	class FtypeDBRecord < BRL::DB::DBRecord
		@@DBTable = nil
		@@colNames = nil

		def initialize(db)
			super(db)
			if(@@DBTable.nil?) then @@DBTable = BRL::Keyword::FtypeDBTable.new(db) end
			if(@@colNames.nil?)
				@@colNames = {}
				colNamesArray = @@DBTable.columnNames()
				colNamesArray.map{ |colName| @@colNames[colName] = '' }
			end
		end

		def [](key)
			begin
				return super(key, @@colNames)
			rescue BRL::DB::TableError
				raise(BRL::DB::TableError, "\nERROR: '#{key}' is not a valid key in table '#{@@DBTable.name}'\n")
			end
		end

		def []=(key, value)
			begin
				return super(key, value, @@colNames)
			rescue BRL::DB::TableError
				raise(BRL::DB::TableError, "\nERROR: '#{key}' is not a valid key in table '#{@@DBTable.name}'\n")
			end
		end
	end # class FtypeDBRecord < BRL::DB::DBRecord

	# ############################################################################
	# 'ftype' table
	# ############################################################################
	class FcategoryDBTable < BRL::DB::DBTable
		@@name = 'fcategory'
		def initialize(db)
			super(@@name, db)
		end
	end

	class FcategoryDBRecord < BRL::DB::DBRecord
		@@DBTable = nil
		@@colNames = nil

		def initialize(db)
			super(db)
			if(@@DBTable.nil?) then @@DBTable = BRL::Keyword::FcategoryDBTable.new(db) end
			if(@@colNames.nil?)
				@@colNames = {}
				colNamesArray = @@DBTable.columnNames()
				colNamesArray.map{ |colName| @@colNames[colName] = '' }
			end
		end

		def [](key)
			begin
				return super(key, @@colNames)
			rescue BRL::DB::TableError
				raise(BRL::DB::TableError, "\nERROR: '#{key}' is not a valid key in table '#{@@DBTable.name}'\n")
			end
		end

		def []=(key, value)
			begin
				return super(key, value, @@colNames)
			rescue BRL::DB::TableError
				raise(BRL::DB::TableError, "\nERROR: '#{key}' is not a valid key in table '#{@@DBTable.name}'\n")
			end
		end
	end # class FtypeDBRecord < BRL::DB::DBRecord

	# ############################################################################
	# 'chr_type_fdata' TEMPLATE table
	# ############################################################################
	class Chr_type_fdata_TEMPLATEDBTable < BRL::DB::DBTable
		@@name = 'chr_type_fdata_TEMPLATE'
		def initialize(actualName, db)
			@name = actualName
			super(@name, db)
		end

		# need dynamic creation method
		def Chr_type_fdata_TEMPLATEDBTable.create(name, dbh)
			# get create table command for template table
			createStr = Chr_type_fdata_TEMPLATEDBTable.getCreateTableCommand(@@name, dbh)
			# replace template table name for our actual name
			createStr.gsub!(/#{@@name}/, name)
			createStr.gsub!(/CREATE TABLE/, 'CREATE TABLE IF NOT EXISTS')
			# create the table
			begin
				dbh.do(createStr)
			end
		end
	end

	class Chr_type_fdata_TEMPLATEDBRecord < BRL::DB::DBRecord
		@@colNames = nil
		attr_reader :name, :DBTable

		def initialize(actualTable, db)
			super(db)
			@DBTable = actualTable
			if(@@colNames.nil?)
				@@colNames = {}
				colNamesArray = @DBTable.columnNames()
				colNamesArray.map{ |colName| @@colNames[colName] = '' }
			end
		end

		def [](key)
			begin
				return super(key, @@colNames)
			rescue BRL::DB::TableError
				raise(BRL::DB::TableError, "\nERROR: '#{key}' is not a valid key in table '#{@name}'\n")
			end
		end

		def []=(key, value)
			begin
				return super(key, value, @@colNames)
			rescue BRL::DB::TableError
				raise(BRL::DB::TableError, "\nERROR: '#{key}' is not a valid key in table '#{@name}'\n")
			end
		end
	end # class Chr_type_fdata_TEMPLATEDBRecord < BRL::DB::DBRecord

	# ############################################################################
	# 'fname_TEMPLATE' TEMPLATE table
	# ############################################################################
	class Fname_TEMPLATEDBTable < BRL::DB::DBTable
		@@name = 'fname_TEMPLATE'
		def initialize(actualName, db)
			@name = actualName
			super(@name, db)
		end

		# need dynamic creation method
		def Fname_TEMPLATEDBTable.create(name, dbh)
			# get create table command for template table
			createStr = Fname_TEMPLATEDBTable.getCreateTableCommand(@@name, dbh)
			# replace template table name for our actual name
			createStr.gsub!(/#{@@name}/, name)
			createStr.gsub!(/CREATE TABLE/, 'CREATE TABLE IF NOT EXISTS')
			# create the table
			begin
				dbh.do(createStr)
			end
		end
	end

	class Fname_TEMPLATEDBRecord < BRL::DB::DBRecord
		@@colNames = nil
		attr_reader :name, :DBTable

		def initialize(actualTable, db)
			super(db)
			@DBTable = actualTable
			if(@@colNames.nil?)
				@@colNames = {}
				colNamesArray = @DBTable.columnNames()
				colNamesArray.map{ |colName| @@colNames[colName] = '' }
			end
		end

		def [](key)
			begin
				return super(key, @@colNames)
			rescue BRL::DB::TableError
				raise(BRL::DB::TableError, "\nERROR: '#{key}' is not a valid key in table '#{@name}'\n")
			end
		end

		def []=(key, value)
			begin
				return super(key, value, @@colNames)
			rescue BRL::DB::TableError
				raise(BRL::DB::TableError, "\nERROR: '#{key}' is not a valid key in table '#{@name}'\n")
			end
		end
	end # class Fname_TEMPLATEDBRecord < BRL::DB::DBRecord

	# ############################################################################
	# 'fname_TEMPLATE' TEMPLATE table
	# ############################################################################
	class Fgroup_TEMPLATEDBTable < BRL::DB::DBTable
		@@name = 'fgroup_TEMPLATE'
		def initialize(actualName, db)
			@name = actualName
			super(@name, db)
		end

		# need dynamic creation method
		def Fgroup_TEMPLATEDBTable.create(name, dbh)
			# get create table command for template table
			createStr = Fgroup_TEMPLATEDBTable.getCreateTableCommand(@@name, dbh)
			# replace template table name for our actual name
			createStr.gsub!(/#{@@name}/, name)
			createStr.gsub!(/CREATE TABLE/, 'CREATE TABLE IF NOT EXISTS')
			# create the table
			begin
				dbh.do(createStr)
			end
		end
	end

	class Fgroup_TEMPLATEDBRecord < BRL::DB::DBRecord
		@@colNames = nil
		attr_reader :name, :DBTable

		def initialize(actualTable, db)
			super(db)
			@DBTable = actualTable
			if(@@colNames.nil?)
				@@colNames = {}
				colNamesArray = @DBTable.columnNames()
				colNamesArray.map{ |colName| @@colNames[colName] = '' }
			end
		end

		def [](key)
			begin
				return super(key, @@colNames)
			rescue BRL::DB::TableError
				raise(BRL::DB::TableError, "\nERROR: '#{key}' is not a valid key in table '#{@name}'\n")
			end
		end

		def []=(key, value)
			begin
				return super(key, value, @@colNames)
			rescue BRL::DB::TableError
				raise(BRL::DB::TableError, "\nERROR: '#{key}' is not a valid key in table '#{@name}'\n")
			end
		end
	end # class Fname_TEMPLATEDBRecord < BRL::DB::DBRecord
end ; end # module BRL ; module Keyword