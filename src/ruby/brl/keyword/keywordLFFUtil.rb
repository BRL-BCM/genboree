#!/usr/bin/env ruby

# ##############################################################################
# REQUIRED LIBRARIES
# ##############################################################################
require 'brl/util/textFileUtil' # For TextReader/Writer convenience classes
require 'dbi'
require 'brl/db/dbrc'						# For brl/db/DBRC class and database nicities
require 'brl/db/util'
require 'brl/keyword/keywordTables'
require 'brl/keyword/keywordDBUtil'
# ##############################################################################
# Turn on extra warnings and such
$VERBOSE = true

module BRL ; module Keyword
	class KeywordLFFUtil
		attr_reader :keywordUtil, :newGroupNames

		def initialize(dbrcFile)
			@keywordUtil = BRL::Keyword::KeywordDBUtil.new(dbrcFile)
			@newGroupNames = {}
		end

		############
		public
		############
		def importFromLFFFile(fileName, typeRecordsHash)
			# go through line-by-line
			lffFile = File.open(fileName)
			lffFile.each {
				|line|
				# split the line
				fields = line.split("\t")
				# check if there is an entrypoint with this fentrypoint_name (must already exist)
				entrypointID = @keywordUtil.getEntrypointID(fields[2])
				if(entrypointID.nil?)
					raise(BRL::Keyword::KeywordDBError, "\nERROR: #{fields[2]} is not an entrypoint in this database\n")
				end
				# check that a category with name class exists, else add it
				categoryID = @keywordUtil.getCategoryID(fields[0])
				if(categoryID.nil?()) # then we don't have an entry for this class yet
					categoryID = @keywordUtil.addCategoryRecord(fields[0], nil, 0)
				end
				# check that we have the fdata's type, else add it
				dataTypeID = @keywordUtil.getTypeID(fields[2], fields[3])
				if(dataTypeID.nil?) # then need to add a new type
					dataTypeID = @keywordUtil.addTypeRecord(fields[2], fields[3], categoryID)
				end
				# check if the name is already in fname...in which case there's a group by that name or a singleton
				nameID = @keywordUtil.getNameID(entrypointID, dataTypeID, fields[1])
				unless(nameID.nil?) # then there's already a name entry in there, which means we have or need to make a new group
					# Is there a group fdata entry?
					groupDataRecord = @keywordUtil.getGroupDataRecord(entrypointID, dataTypeID, nameID)
					unless(groupDataRecord.nil?) # there is already a group record
						# we need to add this latest annotation as a member of the group (we'll update the groups at the end)
						groupDataID = groupDataRecord['fdata_id']
						@newGroupNames[groupDataID] = nameID
					else # there isn't a group record by this name, there's a singleton in there
						# we have to promote to a group, make singleton and this new annotation members, etc
						# need to get the singleton's data record
						singletonDataRecord = @keywordUtil.getDataRecordByName(entrypointID, nameID, dataTypeID)
						# make it into a group, keeping ID for later when we add the new annotation
						groupDataID = @keywordUtil.makeAnnotationIntoGroup(singletonDataRecord)
						@newGroupNames[groupDataID] = nameID
					end
				else # there's no name entry in there, put it in--the annotation is [so far] a groupless singleton
					nameID = @keywordUtil.addNameRecord(entrypointID, dataTypeID, fields[1])
					groupDataID = nil
				end
				dataID = self.insertAnnotation(fields, entrypointID, dataTypeID, nameID)
				# If appropriate, Add a "member" entry to fgroup so we know this is a member of the group
				unless(groupDataID.nil?)
					self.addGroupMember(groupDataID, dataID, 1.0, entrypointID, dataTypeID)
				end
			} # END: lffFile.each
			# Now need to update all the newly added groups with their proper start and stops
			self.updateNewGroups()
		end

		############
		protected
		############
		def updateNewGroups()
			# Get the lists of data and group table names
			detRows = @keywordUtil.detTable("SELECT DISTICT FK_fentrypoint_id, FK_ftype_id FROM fdet")
			# For each new group name
			@newGroupNames.each {
				|groupDataID, nameID|
				# Look in each entrypoint-type pair
				detRows.each {
					|detRow|
					entrypointID = detRow['FK_fentrypoint_id']
					# get the dataTableName for this pair
					dataTableName = @keywordUtil.getTableName(detRow[0], detRow[1], 'fdata')
					# get its min(start) and max(stop)
					row = @keyword.dbh.select_one(
						"SELECT min(fdata_start), min(fdata_stop) " +
						"FROM #{dataTableName} " +
						"WHERE FK_entrypoint_id=#{entrypointID} AND FK_fname_id=#{nameID}")
					# update the group data record with the new start/stop
					self.updateGroup(row[0], row[1], dataTableName, groupDataID)
				}
			}
		end

		def insertAnnotation(fields, entrypointID, typeID, nameID)
			dataTable = @keywordUtil.getTableName(entrypointID, typeID, 'fdata')
			valArray = BRL::Keyword::Chr_type_fdata_TEMPLATEDBRecord.new(dataTable, @keyword.dbh)
			valArray['fdata_id'] = nil
			valArray['fdata_start'], valArray['fdata_stop'] = fields[5].to_i, fields[6].to_i
			valArray['fdata_bin'] = keywordUtil.binCalc.bin(BRL::Keyword::MIN_BIN, fields[5], fields[6])
			valArray['fdata_phase'] = (fields[8] == '.') ? nil : fields[8]
			valArray['fdata_score'], valArray['fdata_strand'] = fields[9].to_f, fields[7]
			if(fields.length > 10)
				valArray['fdata_target_start'], valArray['fdata_target_stop'] = fields[10].to_i, fields[11].to_i
			else
				valArray['fdata_target_start'], valArray['fdata_target_stop'] = nil, nil
			end
			# FK_fname_id
			valArray['FK_fname_id'] = nameID
			# FK_ftype_id, FK_entrypoint_id
			valArray['FK_fentrypoint_id'], valArray['FK_ftype_id'] = typeID, entrypointID

			# Do insert
			dataTable.insert(valArray, true)
			dataID = @keywordUtil.dbh.func(:insert_id)
			return dataID.to_i
		end

		def updateGroup(newStart, newStop, dataTableName, groupDataID)
			newVals = {}
			newVals['fdata_start'] = newStart.to_i
			newVals['fdata_stop'] = newStop.to_i
			dataTable = BRL::Keyword::Chr_type_fdata_TEMPLATEDBTable.new(dataTableName, @keywordUtil.dbh)
			dataTable.update(newVals, "fdata_id=#{groupDataID}")
		end
	end # class KeywordLFFUtil
end ; end 