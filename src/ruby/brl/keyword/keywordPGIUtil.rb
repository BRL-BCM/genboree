#!/usr/bin/env ruby

# ##############################################################################
# REQUIRED LIBRARIES
# ##############################################################################
require 'brl/util/textFileUtil' # For TextReader/Writer convenience classes
require 'dbi'
require 'brl/db/dbrc'						# For brl/db/DBRC class and database nicities
require 'brl/db/util'
require 'brl/keyword/keywordTables'
require 'brl/pgi/pgiTables'
require 'brl/keyword/keywordDBUtil'
# ##############################################################################
# Turn on extra warnings and such
$VERBOSE = true

module BRL ; module Keyword
	class KeywordPGIUtil
		attr_reader :keywordUtil, :pgiDbh, :pgiClass, :pgiType, :pgiSubtypeHash
		attr_reader :pgiIndexTable, :pgiExpTable, :pgiHitsTable, :pgiReadsTable
		attr_reader :expIDStr, :expID
		attr_reader :pgiClass, :newGroupNames

		def initialize(pgiDatabaseName, expIDStr, dbrcFile)
			@pgiDatabaseName = pgiDatabaseName
			@keywordUtil = BRL::Keyword::KeywordDBUtil.new(dbrcFile)
			@pgiDbrc = BRL::DB::DBRC.new(dbrcFile, @pgiDatabaseName)
			@pgiDbh = DBI.connect(@pgiDbrc.driver, @pgiDbrc.user, @pgiDbrc.password)
			@pgiClass = 'BAC'
			@pgiType = 'PGI'
			@pgiSubtypeHash = {2=>'lowConf', 3=>'medConf', 4=>'highConf'}
			@pgiIndexTable = BRL::PGI::PGIIndexDBTable.new(@pgiDbh)
			@pgiExpTable = BRL::PGI::PGIExperimentDBTable.new(@pgiDbh)
			@pgiHitsTable = BRL::PGI::PGIIdxHitsPerPoolDBTable.new(@pgiDbh)
			@pgiReadsTable = BRL::PGI::PGIIdx2ReadsDBTable.new(@pgiDbh)
			@expIDStr = expIDStr
			@expID = getExpID(expIDStr)
			@categoryID = nil
			@newGroupNames = {}
			if(@expID.nil?)
				raise(BRL::Keyword::KeywordDBError, "\nERROR: No pgi experimental record for '#{expIDStr}'\n")
			end
		end

		def importFromPGITables(minIndexOrder)
			bacIndexCount = {}
			# Each PGI Index is a "GROUP" of annotations...the annotations are the mapped reads
			# check that a category with name class exists, else add it
			categoryID = @keywordUtil.getCategoryID(@pgiClass)
			if(categoryID.nil?()) # then we don't have an entry for this class yet
				categoryID = @keywordUtil.addCategoryRecord(@pgiClass, nil, 0)
			end
			# Go through indices table index-by-index. Suck them all in at once--presumed to be small.
			# Otherwise, try using DBI's fetch() to walk through.
			# Otherwise, use a rolling limit start,length on the query to get blocks of results.
			idxRows = @pgiIndexTable.select_all('*', "expID=#{@expID} AND numPoolsWithHits >= #{minIndexOrder} ")
			idxRows.each {
				|idxRow|
				# 0) check if there is an entrypoint with this fentrypoint_name (must already exist)
				entrypointID = @keywordUtil.getEntrypointID(idxRow['targetName'])
				if(entrypointID.nil?)
					raise(BRL::Keyword::KeywordDBError, "\nERROR: #{idxRow['targetName']} is not an entrypoint in this keyword database\n")
				end

				# 1) Index Count for BAC:
				bacName = idxRow['bacName'].strip
				if(bacIndexCount.key?(bacName)) # then it's not the first index for this BAC...
					bacIndexCount[bacName] += 1
				else # it's the first index for this BAC...
					bacIndexCount[bacName] = 1
				end
				uniqIndexName = "#{bacName}.#{bacIndexCount[bacName]}"

				# check if type:subtype is a valid type record
				dataTypeID = @keywordUtil.getTypeID(@pgiType, @pgiSubtypeHash[idxRow['numPoolsWithHits']])
				if(dataTypeID.nil?) # then need to add a new type
					dataTypeID = self.addNewPGIType(idxRow['numPoolsWithHits'], categoryID)
				end

				# 2) Make the group corresponding to this index
				# get any existing nameID for this group if it's already in there
				groupNameID = @keywordUtil.getNameID(entrypointID, dataTypeID, uniqIndexName)
#				unless(nameID.nil?) # The group's name is in there, that doesn't make sense, we're just adding it now! :)
#					raise(KeywordDBError, "\nERROR: PGI group #{uniqIndexName} already exists?\n")
#				end
				if(groupNameID.nil?)
					# we need to add the name record
					groupNameID = @keywordUtil.addNameRecord(entrypointID, dataTypeID, uniqIndexName)
				end
				groupDataID = @keywordUtil.getGroupDataID(entrypointID, dataTypeID, groupNameID)
				if(groupDataID.nil?)
					# we need to add the group data record
					groupDataID = self.createGroup(idxRow, entrypointID, dataTypeID, groupNameID)
				end
				# Now insert the new annotation record
				dataID = self.insertAnnotation(idxRow, entrypointID, groupDataID, dataTypeID)
			}
			# No Need to update all the group's fdata so the group has proper start/stop, since for PGI indices we already know the group start/stop apriori
			# self.updateNewGroups()
		end

		###########
		protected
		###########
		def getExpID(expIDStr)
			row = @pgiExpTable.select_one('id', "idStr='#{expIDStr}'")
			return (row.nil?) ? nil : row[0]
		end

		def addNewPGIClass()
			# if a category ID like this doesn't already exist, create it
			row = @keywordUtil.categoryTable.select_one('fcategory_id', "fcategory_name='#{@pgiClass}'")
			if(row.nil?) # then doesn't exist, need to add it
				categoryID = @keywordUtil.addCategoryRecord(@pgiClass, nil, 0.0)
			else # exists, just return existing id
				categoryID = row[0]
			end
			return categoryID
		end

		def addNewPGIType(indexOrder, categoryID)
			# create a new ftype record, using appropriate subtype
			return @keywordUtil.addTypeRecord(@pgiType, @pgiSubtypeHash[indexOrder], categoryID)
		end

		def getReadList(pgiIdxID)
			rows = @pgiReadsTable.select_all('*', "pgiIdxID=#{pgiIdxID}")
			return rows
		end

		def insertAnnotation(idxRow, entrypointID, groupDataID, typeID)
			# get the list of reads for this pgiIndex
			readRecords = self.getReadList(idxRow['id'])
			# need a new fdata for the group, but we have to find the right tables first
			dataTable = @keywordUtil.getTableObj(entrypointID, typeID, 'fdata')
			#  For each mapped read in the index, add them as fdata and as members of the "GROUP"
			readRecords.each {
				|readRecord|
				readName = readRecord['readName']
				# We need to store the read name in the name table first
				# Only add it if this is the first time we put this read in
				nameID = @keywordUtil.getNameID(entrypointID, typeID, readName)
				if(nameID.nil?) # then never seen this read before, better add it
					nameID = @keywordUtil.addNameRecord(entrypointID, typeID, readName)
				end
				# Let's create the new record
				dataRecord = BRL::Keyword::Chr_type_fdata_TEMPLATEDBRecord.new(dataTable, @keywordUtil.dbh)
				dataRecord['fdata_id'] = nil
				readStart = readRecord['readStartOnTarget'].to_i + 1
				readStop = readStart + readRecord['readLength'].to_i - 1
				dataRecord['fdata_start'] = readStart
				dataRecord['fdata_stop'] = readStop
				dataRecord['fdata_bin'] = @keywordUtil.binCalc.bin(BRL::Keyword::MIN_BIN, readStart, readStop)
				dataRecord['fdata_phase'] = nil
				dataRecord['fdata_score'] = 1.0
				dataRecord['fdata_strand'] = nil
				dataRecord['fdata_target_start'] = 1
				dataRecord['fdata_target_stop'] = readRecord['readLength'].to_i
				dataRecord['FK_fname_id'] = nameID
				dataRecord['FK_fentrypoint_id'] = entrypointID
				dataRecord['FK_ftype_id'] = typeID
				# Do insert if exact annotation is not already in there
				whereStr = "(FK_fentrypoint_id=#{entrypointID} AND fdata_bin=#{dataRecord['fdata_bin']} AND fdata_start=#{readStart} AND fdata_stop=#{readStop} AND FK_ftype_id=#{typeID}) AND "
				whereStr << "FK_fname_id=#{nameID} AND fdata_score=1.0 AND fdata_phase IS NULL AND fdata_target_start=1 AND fdata_target_stop=#{dataRecord['fdata_target_stop']}"
				row = dataTable.select_one('fdata_id', whereStr)
				if(row.nil?)
					dataTable.insert(dataRecord, true)
					dataID = @keywordUtil.dbh.func(:insert_id)
				else
					dataID = row[0]
				end
				# Add a "member" entry to fgroup so we know this is a member of the group
				@keywordUtil.addGroupMember(groupDataID, dataID, 1.0, entrypointID, typeID)
			}
		end

		def createGroup(idxRow, entrypointID, typeID, groupNameID)
			start = idxRow['idxStart'].to_i + 1
			stop = idxRow['idxEnd'].to_i
			# need a new fdata for the group, but we have to find the right table first
			dataTable = @keywordUtil.getTableObj(entrypointID, typeID, 'fdata')
			# Let's create the new record
			dataRecord = BRL::Keyword::Chr_type_fdata_TEMPLATEDBRecord.new(dataTable, @keywordUtil.dbh)
			dataRecord['fdata_id'] = nil
			dataRecord['fdata_start'] = start
			dataRecord['fdata_stop'] = stop
			dataRecord['fdata_bin'] = @keywordUtil.binCalc.bin(BRL::Keyword::MIN_BIN, start, stop)
			dataRecord['fdata_phase'] = nil
			dataRecord['fdata_score'] = idxRow['numPoolsWithHits']
			dataRecord['fdata_strand'] = nil
			dataRecord['fdata_target_start'] = nil
			dataRecord['fdata_target_stop'] = nil
			dataRecord['FK_fname_id'] = groupNameID
			dataRecord['FK_fentrypoint_id'] = entrypointID
			dataRecord['FK_ftype_id'] = typeID
			# Now insert it
			dataTable.insert(dataRecord, true)
			groupDataID = @keywordUtil.dbh.func(:insert_id)
			# We want to track all new groups
			@newGroupNames[groupDataID] = groupNameID
			return groupDataID
		end

		def updateNewGroups()
			# Get the lists of data and group table names
			detRows = @keywordUtil.detTable("SELECT DISTICT FK_fentrypoint_id, FK_ftype_id FROM fdet")
			# For each new group name
			@newGroupNames.each {
				|groupDataID, nameID|
				# Look in each entrypoint-type pair
				@keywordUtil.detLookupHash.each {
					|entrypointID, typeHash|
					typeHash.each {
						|typeID, datatocHash|
						datatocHash.each {
							|datatocID, val|
							# get the dataTableName for this pair
							dataTableName = @keywordUtil.getTableName(entrypointID, typeID, 'fdata')
							# get its min(start) and max(stop)
							row = @keyword.dbh.select_one(
								"SELECT min(fdata_start) FROM #{dataTableName} " +
								"WHERE FK_entrypoint_id=#{entrypointID} AND FK_fname_id=#{nameID}")
							minStart = row[0]
							row = @keyword.dbh.select_one(
								"SELECT max(fdata_sttop) FROM #{dataTableName} " +
								"WHERE FK_entrypoint_id=#{entrypointID} AND FK_fname_id=#{nameID}")
							maxStop = row[0]
							# update the group data record with the new start/stop
							self.updateGroup(minStart, maxStop, dataTableName, groupDataID)
						}
					}
				}
			}
		end

		def updateGroup(newStart, newStop, dataTableName, groupDataID)
			newVals = {}
			newVals['fdata_start'] = newStart.to_i
			newVals['fdata_stop'] = newStop.to_i
			dataTable = BRL::Keyword::Chr_type_fdata_TEMPLATEDBTable.new(dataTableName, @keywordUtil.dbh)
			dataTable.update(newVals, "fdata_id=#{groupDataID}")
		end
	end # class KeywordPGIUtil
end ; end