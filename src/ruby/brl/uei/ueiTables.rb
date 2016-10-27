#!/usr/bin/env ruby
# Turn on extra warnings and such
$VERBOSE = true

# ##############################################################################
# REQUIRED LIBRARIES
# ##############################################################################
require 'brl/util/textFileUtil' # For TextReader/Writer convenience classes
require 'dbi'
require 'brl/db/dbrc'						# For brl/db/DBRC class and database nicities
require 'brl/db/util'						# For possibly useful table abstraction
# ##############################################################################

# FOR REF
# ruby -e 'require "dbi"; require "brl/db/dbrc"; dbrc = BRL::DB::DBRC.new("~/.dbrc", "andrewj_ucsc_hg13"); dbh = DBI.connect(dbrc.driver, dbrc.user, dbrc.password);dbh.columns("xenoEst").each{|cc| print cc.name; puts "\t>>#{cc.default}<<\tnullOK? #{cc.nullable}"; };'
#

module BRL ; module UEI
	class UEIDBTable < BRL::DB::DBTable
		@@name = 'uei'
		def initialize(db)
			super(@@name, db)
		end
	end

	class UEIDBRecord < BRL::DB::DBRecord
		@@DBTable = nil
		@@colNames = nil

		def initialize(db)
			super(db)
			if(@@DBTable.nil?) then @@DBTable = BRL::UEI::UEIDBTable.new(db) end
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
	end # class UEIDBRecord < BRL::DB::DBRecord
end ; end # module BRL ; module UEI
