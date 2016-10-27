#!/usr/bin/env ruby

# ##############################################################################
# REQUIRED LIBRARIES
# ##############################################################################
require 'brl/util/textFileUtil' # For TextReader/Writer convenience classes
require 'dbi'
require 'brl/db/dbrc'						# For brl/db/DBRC class and database nicities
require 'brl/db/util'
require 'brl/keyword/keywordTables'
require 'brl/sql/binning'
# ##############################################################################
# Turn on extra warnings and such
$VERBOSE = true

module BRL ; module Keyword
	MIN_BIN = 1000
	DB_LOCK_NAME = 'entrypoint_update'
	DB_LOCK_TIMEOUT = 600

	class KeywordDBError < StandardError ; end

	class KeywordDBUtil
		attr_accessor :dbrc, :dbh, :binCalc
		attr_accessor :typeTable, :keywordTable, :keywordKeywordTable, :detTable, :datatocTable, :entrypointTable, :categoryTable
		attr_accessor :tableLookupHash, :typeLookupHash, :datatocLookupHash, :typeLookupHash
		attr_accessor :categoryLookupHash, :entrypointLookupHash, :detLookupHash

		DEF_GROUP_TYPE = 'group'
		FDATA, FLINK, FNOTE, FSEQUENCE, FDATA_TO_FLINK, FDATA_TO_FSEQUENCE, FDATA_TO_FNOTE, FGROUP, FNAME =
		 'fdata', 'flink', 'fnote', 'fsequence', 'fdata_to_flink', 'fdata_to_fsequence', 'fdata_to_fnote', 'fgroup', 'fname'
		@@databaseName = 'andrewj_keyword'
		ENTRYPOINT_NAME, FK_FDATATOC_ID, FK_FDATA_ID = 0,1,2
		DATATOC_REC, DATATOC_OBJ = 0,1

		def initialize(dbrcFile)
			@dbrc = BRL::DB::DBRC.new(dbrcFile, @@databaseName)
			@dbh = DBI.connect(dbrc.driver, dbrc.user, dbrc.password)
			@binCalc = BRL::SQL::Binning.new()
			# Let's set up some table objects to use (save time)
			@typeTable = BRL::Keyword::FtypeDBTable.new(@dbh)
			@keywordTable = BRL::Keyword::KeywordDBTable.new(@dbh)
			@keywordKeywordTable = BRL::Keyword::Keyword_KeywordDBTable.new(@dbh)
			@dataKeywordTable = BRL::Keyword::FdatakeywordDBTable.new(@dbh)
			@detTable = BRL::Keyword::FdetDBTable.new(@dbh)
			@datatocTable = BRL::Keyword::FdatatocDBTable.new(@dbh)
			@entrypointTable = BRL::Keyword::FentrypointDBTable.new(@dbh)
			@categoryTable = BRL::Keyword::FcategoryDBTable.new(@dbh)
			@tableLookupHash = {}
			@datatocLookupHash = {}
			@typeLookupHash = {}
			@categoryLookupHash = {}
			@entrypointLookupHash = {}
			@detLookupHash = {}
			# cache the table objects in the tableLookupHash and datatocHash
			recacheDatatocInfo()
			recacheDETLookup()
			recacheTypeLookup()
			recacheCategoryLookup()
			recacheEntrypointLookup()
			recacheTableObjects()
		end

		def lockDB()
			lockSql = "SELECT GET_LOCK(\"#{DB_LOCK_NAME}\", #{DB_LOCK_TIMEOUT})"
			row = @dbh.select_one(lockSql)
			return (row.nil?) ? nil : row[0]
		end

		def unlockDB()
			unlockSql = "SELECT RELEASE_LOCK(\"#{DB_LOCK_NAME}\")"
			row = @dbh.select_one(unlockSql)
			return (row.nil?) ? nil : row[0]
		end

		def recacheDETLookup()
			# select all records from the fdet table
			rows = @detTable.select_all('*')
			# add those ones that don't already have entries
			rows.each {
				|row|
				datatocID, entrypointID, typeID = row[0], row[1], row[2]
				# update cache as necessary
				unless(@detLookupHash.key?(entrypointID)) then @detLookupHash[entrypointID] = {}; end
				unless(@detLookupHash[entrypointID].key?(typeID)) then @detLookupHash[entrypointID][typeID] = {} ; end
				unless(@detLookupHash[entrypointID][typeID].key?(datatocID)) then @detLookupHash[entrypointID][typeID][datatocID] = ''; end
			}
		end

		def recacheEntrypointLookup()
			# select all records from the fentrypoint table
			rows = @entrypointTable.select_all('fentrypoint_id, fentrypoint_name, FK_fdatatoc_id, FK_fdata_id');
			rows.each {
				|row|
				entrypointID = row[0]
				name = row[1]
				datatocID = row[2]
				dataID = row[3]
				# update cache as necessary
				unless(@entrypointLookupHash.key?(entrypointID))
					@entrypointLookupHash[entrypointID] = [ name, datatocID, dataID ]
				end
			}
		end

		def recacheCategoryLookup()
			# select all records from the fcategory table
			rows = @categoryTable.select_all('fcategory_id, fcategory_name');
			rows.each {
				|row|
				name = row[1]
				categoryID = row[0]
				# update cache as necessary
				unless(@categoryLookupHash.key?(name)) then @categoryLookupHash[name] = categoryID; end
			}
		end

		def recacheTypeLookup()
			# select all records from the ftype table
			rows = @typeTable.select_all('*');
			rows.each {
				|row|
				type = row[1]
				subtype = row[2]
				typeID = row[0]
				# update cache as necessary
				unless(@typeLookupHash.key?(type)) then @typeLookupHash[type] = {}; end
				unless(@typeLookupHash[type].key?(subtype)) then	@typeLookupHash[type][subtype] = typeID; end
			}
		end

		def recacheDatatocInfo
			# Get all the datatoc records
			datatocRows = @datatocTable.select_all('*')
			datatocRows.each {
				|datatocRow|
				datatocID = datatocRow[0]
				# create the hash of hashes we need
				unless(@datatocLookupHash.key?(datatocID)) # then haven't seen this datatoc already
					datatocRecord = BRL::Keyword::FdatatocDBRecord.new(@dbh)
					# fill in the information
					@datatocTable.columnNames.each {
						|colName|
						datatocRecord[colName] = datatocRow[colName]
					}
					# create a table object for this table
					case datatocRecord['fdatatoc_type']
						when FDATA
							tableObj = BRL::Keyword::Chr_type_fdata_TEMPLATEDBTable.new(datatocRecord['fdatatoc_name'], @dbh)
						when FGROUP
							tableObj = BRL::Keyword::Fgroup_TEMPLATEDBTable.new(datatocRecord['fdatatoc_name'], @dbh)
						when FNAME
							tableObj = BRL::Keyword::Fname_TEMPLATEDBTable.new(datatocRecord['fdatatoc_name'], @dbh)
					end
					@datatocLookupHash[datatocID] = [ datatocRecord, tableObj ]
				end
			}
		end

		def recacheTableObjects()
			# For each det record, get the fdatatoc record for the datatoc_id.
			# det info is cached
			@detLookupHash.each {
				|entrypointID, typeHash|
				typeHash.each {
					|typeID, datatocHash|
					datatocHash.each {
						|datatocID, val|
						# create the hash of hashes we need to find tables fast by ep, type, tableType
						unless(@tableLookupHash.key?(entrypointID)) then @tableLookupHash[entrypointID] = {}; end
						unless(@tableLookupHash[entrypointID].key?(typeID)) then @tableLookupHash[entrypointID][typeID] = {}; end
						# datatoc records and table objects are cached also
						datatocInfo = @datatocLookupHash[datatocID]
						datatocRec, datatocObj = datatocInfo[DATATOC_REC], datatocInfo[DATATOC_OBJ]
						tableType = datatocRec['fdatatoc_type']
						# add a table object for the table if not there already
						unless(@tableLookupHash[entrypointID][typeID].key?(tableType))
							@tableLookupHash[entrypointID][typeID][tableType] = datatocObj
						end
					}
				}
			}
		end

		def getAllTypeRecords
			# this info is cached
			retHash = {}
			@typeLookupHash.each {
				|type, typeHash|
				typeHash.each {
					|subtype, typeID|
					retHash["#{type}:#{subtype}"] = typeID
				}
			}
			# return hash of type:subtype to type_ids
			return retHash
		end

		def addTypeRecord(type, subtype, categoryID)
			# Should we add it or is it already there? Use cache to answer this
			typeID = nil
			# Look for it in type cache
			if(@typeLookupHash.key?(type))
				if(@typeLookupHash[type].key?(subtype))
					# found it already in here, we are done
					return @typeLookupHash[type][subtype]
				end
			end
			# else didn't find it, add it
			@typeTable.insert( [ nil, type, subtype, categoryID ] )
			typeID = @dbh.func(:insert_id)
			# update type cache
			unless(@typeLookupHash.key?(type)) then @typeLookupHash[type] = {}; end
			@typeLookupHash[type][subtype] = typeID
			# Need to make sure det is updated. In this first version, we'll be having 1 tableSet per chromosome
			# So for each chromosome, make sure it set of fdata,fgroup,fname can be found by entrypoint & this
			# new type.
			# For each entrypoint, do a safe insert into the fdet table for each table type
			@entrypointLookupHash.each {
				|entrypointID, entrypointInfo|
				[FDATA, FNAME, FGROUP].each {
					|tableType|
					# Get the datatocID for this entrypoint and tableType
					# ASSUMPTION: for now, assume ALL the annotation data for 1 chromosome is in a single table (no breaking chromosome data by type)
					row = @dbh.select_one("SELECT fdet.FK_fdatatoc_id FROM fdet,fdatatoc WHERE fdet.FK_fdatatoc_id=fdatatoc.fdatatoc_id AND fdatatoc.fdatatoc_type='#{tableType}' AND fdet.FK_fentrypoint_id=#{entrypointID}")
					if(row.nil?)
						raise(KeywordDBError, "\nERROR: no tables associated with entrypoint # #{entrypointID}? Inconsistent database!\n")
					end
					datatocID = row[0]
					@detTable.insert([ datatocID, entrypointID, typeID ], true)
					# update det cache
					unless(@detLookupHash.key?(entrypointID)) then @detLookupHash[entrypointID] = {}; end
					unless(@detLookupHash[entrypointID].key?(typeID)) then @detLookupHash[entrypointID][typeID] = {} ; end
					unless(@detLookupHash[entrypointID][typeID].key?(datatocID)) then @detLookupHash[entrypointID][typeID][datatocID] = ''; end
				}
			}
			# Now recache fdet table information. Don't need to recache datatoc info since we didn't
			# add a new set of tables.
			self.recacheTableObjects()
			return typeID
		end

		def addNameRecord(entrypointID, typeID, name)
			nameTable = getTableObj(entrypointID, typeID, 'fname')
			nameTable.insert([ nil, name ])
			nameID = @dbh.func(:insert_id)
			return nameID
		end

		def getNameID(entrypointID, typeID, name)
			nameTable = getTableObj(entrypointID, typeID, 'fname')
			row = nameTable.select_one('fname_id', "fname_value='#{name}'")
			return row.nil?() ? nil : row[0]
		end

		def getTypeID(type, subtype)
			# this info is cached
			typeID = nil
			if(@typeLookupHash.key?(type))
				if(@typeLookupHash[type].key?(subtype))
					typeID = @typeLookupHash[type][subtype]
				end
			end
			return typeID
		end

		def getCategoryRecord(name)
			row = @categoryTable.select_one('*', "fcategory_name='#{name}'")
			return row.nil?() ? nil : row
		end

		def getCategoryID(name)
			# this info is cached
			if(@categoryLookupHash.key?(name)) then return @categoryLookupHash[name]; end
			return nil # not found
		end

		def addCategoryRecord(name, description, order)
			# this info is cached. If it's in there, return it, otherwise add and update cache
			if(@categoryLookupHash.key?(name))
				categoryID = @categoryLookupHash[name]
			else # it's a new one
				@categoryTable.insert([ nil, name, description, order ])
				categoryID = @dbh.func(:insert_id)
				# update cache
				@categoryLookupHash[name] = categoryID
			end
			return categoryID
		end

		def addDatatocRecord(name, tableType)
			# this info is cached. If it's in there, return it, otherwise add and update cache
			datatocID = nil
			@datatocLookupHash.each {
				|tocID, datatocInfo|
				datatocRecord = datatocInfo[DATATOC_REC]
				if(datatocRecord['fdatatoc_name'] == name) # found it cached already
					return datatocID
				end
			}
			# else didn't find it...add to table and to cache
			# create a record for it
			datatocRecord = BRL::Keyword::FdatatocDBRecord.new(@dbh)
			datatocRecord['fdatatoc_id'] = nil
			datatocRecord['fdatatoc_name'] = name
			datatocRecord['fdatatoc_type'] = tableType
			@datatocTable.insert(datatocRecord)
			datatocID = @dbh.func(:insert_id)
			# create a table object for it
			case tableType
				when FDATA
					tableObj = BRL::Keyword::Chr_type_fdata_TEMPLATEDBTable.new(datatocRecord['fdatatoc_name'], @dbh)
				when FGROUP
					tableObj = BRL::Keyword::Fgroup_TEMPLATEDBTable.new(datatocRecord['fdatatoc_name'], @dbh)
				when FNAME
					tableObj = BRL::Keyword::Fname_TEMPLATEDBTable.new(datatocRecord['fdatatoc_name'], @dbh)
			end
			# update cache
			@datatocLookupHash[datatocID] = [ datatocRecord, tableObj ]
			return datatocID
		end

		def addEntrypointRecord(name, desc, datatocID, dataID)
			# this info is cached. If it's in there, return it, otherwise add and update cache
			entrypointID = nil
			@entrypointLookupHash.each {
				|entrypointID, entrypointArray|
				if(entrypointArray[ENTRYPOINT_NAME] == name)
					return entrypointID
				end
			}
			# else didn't find it...add to table and to cache
			@entrypointTable.insert( [nil, name, desc, datatocID, dataID] )
			entrypointID = @dbh.func(:insert_id)
			@entrypointLookupHash[entrypointID] = [ name, datatocID, dataID ]
			return entrypointID
		end

		def updateEntrypointTable(entrypointID, dataID)
			@entrypointTable.update( { 'FK_fdata_id' => dataID }, "fentrypoint_id=#{entrypointID}")
			# update cache too
			@entrypointLookupHash[entrypointID][FK_FDATA_ID] = dataID
		end

		def addDetRecord(datatocID, entrypointID, typeID)
			# this info is cached. If it's in there, do nothing, otherwise add and update cache
			unless(@detLookupHash.key?(entrypointID)) then @detLookupHash[entrypointID] = {}; end
			unless(@detLookupHash[entrypointID].key?(typeID)) then @detLookupHash[entrypointID][typeID] = {} ; end
			unless(@detLookupHash[entrypointID][typeID].key?(datatocID)) # then it's not there already
				@detLookupHash[entrypointID][typeID][datatocID] = ''
				@detTable.insert( [datatocID, entrypointID, typeID], true)
			end
		end

		def getGroupDataID(entrypointID, typeID, name)
			row = self.getGroupDataRecord(entrypointID, typeID, name)
			return row.nil?() ? nil : row[0].to_i
		end

		def addGroupMember(groupDataID, dataID, score, entrypointID, dataTypeID)
			dataTable = self.getTableObj(entrypointID, dataTypeID, 'fgroup')
			# Ignore duplicate group-member associations
			dataTable.insert( [ groupDataID, dataID, score ], true )
		end

		def getGroupDataRecord(entrypointID, typeID, name)
			# First, get name entry for this group, if necessary
			if(name.kind_of?(String)) # else, assume it's an fname_id
				nameTable = self.getTableObj(entrypointID, typeID, 'fname')
				row = nameTable.select_one('fname_id', "fname_value='#{name}'")
				unless(row.nil?())
					nameID = row[0]
				else # oh oh, no such group...can't get a record for it since it doesn't exist
					return nil
				end
			else # name arg must BE the id
				nameID = name
			end
			# Now get the fdata record with this name that are groups. It's the one associated with the name id.
			dataTable = self.getTableObj(entrypointID, typeID, 'fdata')
			dataTableName = dataTable.name
			row = @dbh.select_one(
				"SELECT * FROM #{dataTableName} AS fdata " +
				"WHERE fdata.FK_fentrypoint_id=#{entrypointID} AND " +
				"fdata.FK_fname_id=#{nameID} AND fdata.FK_ftype_id=#{typeID}")
			return row.nil?() ? nil : row
		end

		def getDataRecordByName(entrypointID, name, typeID)
			# First, get name entry, if necessary
			if(name.kind_of?(String)) # else, assume it's an fname_id
				nameTable = self.getTableObj(entrypointID, typeID, 'fname')
				row = nameTable.select_one('fname_id', "fname_value='#{name}'")
				unless(row.nil?())
					nameID = row[0]
				else # oh oh, no such name...can't get a record for it since it doesn't exist
					return nil
				end
			else # name arg must BE the id
				nameID = name
			end
			# Now get the fdata record with this name that are groups
			dataTable = self.getTableObj(entrypointID, typeID, 'fdata')
			row = @dataTable.select_one('*', "FK_fentrypoint_id=#{entrypointID} AND FK_fname_id=#{nameID} AND FK_ftype_id=#{typeID}")
			return row.nil?() ? nil : row
		end

		# Given an fdata item turn it into a group as well, make the fdata a member of this group
		# and return the new group's ID
		def makeAnnotationIntoGroup(annotationRecord, entrypointID, typeID)
			# Our new record object:
			groupDataRecord = BRL::Keyword::Chr_type_fdata_TEMPLATEDBRecord.new(dataTable, @dbh)
			groupDataRecord['fdata_id'] = nil
			groupDataRecord['fdata_start'] = annotationRecord['fdata_start']
			groupDataRecord['fdata_stop'] = annotationRecord['fdata_stop']
			groupDataRecord['fdata_bin'] = annotationRecord['fdata_bin']
			groupDataRecord['fdata_phase'] = nil
			groupDataRecord['fdata_score'] = 0.0
			groupDataRecord['fdata_strand'] = nil
			groupDataRecord['fdata_target_start'] = annotationRecord['fdata_target_start']
			groupDataRecord['fdata_target_stop'] = annotationRecord['fdata_target_stop']
			groupDataRecord['FK_fname_id'] = annotationRecord['FK_fname_id'] # group's name is singleton's name
			groupDataRecord['FK_entrypoint_id'] = annotationRecord['FK_entrypoint_id']
			groupDataRecord['FK_ftype_id'] = annotationRecord['FK_ftype_id']
			# insert it into fdata table:
			dataTable = self.getTableObj(entrypointID, typeID, 'fdata')
			dataTable.insert(groupDataRecord)
			groupDataID = @keywordUtil.dbh.func('insert_id()')
			# Add original fdata as member of this group
			self.addGroupMember(groupDataID, dataID, 1.0, annotationRecord['FK_entrypoint_id'], annotationRecord['FK_ftype_id'])
			return groupDataID
		end

		def getDatatocID(entrypointID, typeID, tableType)
			unless(@detLookupHash.key?(entrypointID)) then return nil ; end
			unless(@detLookupHash[entrypointID].key?(typeID)) then return nil ; end
			@detLookupHash[entrypointID][typeID].each {
				|datatocID, val|
				if(@datatocLookupHash[datatocID][DATATOC_REC]['fdatatoc_type'] = tableType)
					return datatocID
				end
			}
			return nil
		end

		def addKeywordToKeywordAssociation(keywordID1, relationType, keywordID2)
			status = @keywordKeywordTable.insert( [ nil, keywordID1, keywordID2, relationType ], true)
			if(status >= 1)
				keywordKeywordID = @dbh.func(:insert_id)
			else # already in there, get the ID
				keywordKeywordID = self.getKeywordToKeywordAssociationID(keywordID1, relationType, keywordID2)
			end
			return keywordKeywordID
		end

		def getKeywordToKeywordAssociationID(keywordID1, relationType, keywordID2)
			row = @keywordKeywordTable.select_one('id', "keyword1_id=#{keywordID1} AND relationType='#{relationType}' AND keyword2_id=#{keywordID2}")
			return row.nil?() ? nil : row[0]
		end

		def addDataToKeywordAssociation(dataID, datatocID, relationType, keywordID)
			status = @dataKeywordTable.insert( [ nil, dataID, datatocID, keywordID, relationType ], true)
			if(status >= 1)
				assocID = @dbh.func(:insert_id)
			else # already in there, get the ID
				assocID = self.getKeywordAssociationID(dataID, datatocID, relationType, keywordID)
			end
			return assocID
		end

		def getDatatocIDByName(tableName)
			# this info is cached
			@datatocLookupHash.each {
				|datatocID, datatocInfo|
				datatocRecord = datatocInfo[DATATOC_REC]
				if(datatocRecord['fdatatoc_name'] == tableName) then return datatocID; end
			}
			return nil # not found
		end

		def getDatatocInfoByTableType(tableType)
			datatocHash = {}
			# this info is cached
			@datatocLookupHash.each {
				|datatocID, datatocInfoArray|
				datatocRecord = datatocInfoArray[DATATOC_REC]
				if(datatocRecord['fdatatoc_type'] == tableType)
					datatocHash[datatocID] = datatocInfoArray
				end
			}
			return datatocHash
		end

		def getTableName(entrypointID, typeID, tableType)
			tableObj = self.getTableObj(entrypointID, typeID, tableType)
			return tableObj.nil?() ? nil : tableObj.name
		end

		def getTableObj(entrypointID, typeID, tableType)
			unless(@tableLookupHash.key?(entrypointID)) then return nil; end
			unless(@tableLookupHash[entrypointID].key?(typeID)) then return nil; end
			tableObj = @tableLookupHash[entrypointID][typeID][tableType]
			return tableObj
		end

		def getEntrypointID(entrypointName)
			# this info is cached
			@entrypointLookupHash.each {
				|entrypointID, entrypointArray|
				if(entrypointArray[ENTRYPOINT_NAME] == entrypointName) then return entrypointID; end
			}
			return nil # not found
		end

		def getEntrypointIDs()
			# this info is cached
			return @entrypointLookupHash.keys
		end

		def getKeywordID(keywordClass, type, keyword)
			row = @keywordTable.select_one('keyword_id', "keyword_class='#{keywordClass}' AND keyword_type='#{type}' AND keyword_value=#{@dbh.quote(keyword)}")
			return row.nil?() ? nil : row[0]
		end

		def getKeywords(keywordClass, keywordType)
			keywords = {}
			rows = @keywordTable.select_all('keyword_id, keyword_value', "keyword_class='#{keywordClass}' AND keyword_type='#{keywordType}'")
			rows.each {
				|row|
				keywords[row[1]] = row[0]
			}
			return keywords
		end

		def getKeywordAssociationID(dataID, datatocID, relationType, keywordID)
			row = @dataKeywordTable.select_one('id', "fdata_id=#{dataID} AND fdatatoc_id=#{datatocID} AND relationType='#{relationType}' AND keyword_id=#{keywordID}")
			return row.nil?() ? nil : row[0]
		end

		def addKeywordRecord(keywordClass, type, keyword)
			status = @keywordTable.insert( [nil, keywordClass, type, keyword], true)
			if(status >= 1)
				keywordID = @dbh.func(:insert_id)
			else # not inserted, must have already been there, get the id
				keywordID = self.getKeywordID(keywordClass, type, keyword)
			end
			return keywordID
		end
	end
end ; end
