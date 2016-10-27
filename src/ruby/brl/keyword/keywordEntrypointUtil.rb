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
	class KeywordEntrypointUtil
		attr_reader :keywordUtil

		ST_START, ST_REF_POINTS, ST_ASSEMBLY, ST_END = 0,1,2,3
		FDATA, FGROUP, FNAME = 0,1,2
		CHROMOSOME_TYPE = 'Component'
		CHROMOSOME_SUBTYPE = 'Chromosome'
		CHROMOSOME_CATEGORY = 'Chromosome'

		def initialize(dbrcFile)
			@keywordUtil = BRL::Keyword::KeywordDBUtil.new(dbrcFile)
			@tableList =
				[ @keywordUtil.typeTable, @keywordUtil.detTable, @keywordUtil.datatocTable, @keywordUtil.entrypointTable, @keywordUtil.categoryTable ]
		end

		############
		public
		############
		def importFromLDASFile(fileName)
			begin
				# First, let's "lock" the database tables.
				# Because of all the dynamic table creation, and that "UNLOCK TABLES" unlocks
				# everything, our solution is to set a named-lock to prevent other people &
				# applications from doing the same sort of work at the same time. This is
				# *cooperative* locking--all applications agree to obtain/release this named
				# lock before/after doing their work.
				lockReply = @keywordUtil.lockDB()
				if(lockReply.nil?)
					raise(BRL::Keyword::KeywordDBError, "\nERROR: lock SQL returned NULL, this is very bad since it indicates huge issue with database. Track this down!\n")
				elsif(lockReply == 0)
					raise(BRL::Keyword::KeywordDBError, "\nERROR: the shared lock is set and timed out after many minutes. Is another process doing a big insert or did you not release your lock?!\n")
				end
				# Do we have a category id for Chromosome yet? If not, add it.
				categoryID = @keywordUtil.getCategoryID(CHROMOSOME_CATEGORY)
				if(categoryID.nil?)
					categoryID = @keywordUtil.addCategoryRecord(CHROMOSOME_CATEGORY, nil, 0)
				end
				# Do we have a type for Component:Chromosome yet? If not, add it.
				typeID = @keywordUtil.getTypeID(CHROMOSOME_TYPE, CHROMOSOME_SUBTYPE)
				if(typeID.nil?)
					typeID = @keywordUtil.addTypeRecord(CHROMOSOME_TYPE, CHROMOSOME_SUBTYPE, categoryID)
				end
				state = ST_START
				# We'll read line at a time and track state. Terminal state is seeing
				# EOF or [annotations] section
				lineCount = 0
				lffFile = File.open(fileName)
				lffFile.each {
					|line|
					lineCount += 1
					next if((line =~ /^\s*#/) or (line =~ /^\s*$/)) # skip comments and blank lines
					if(state == ST_END)
						break
					elsif(state == ST_START)
						if(line =~ /^\s*\[reference_points\]/)
							state = ST_REF_POINTS
						end
					elsif(state == ST_REF_POINTS and line !~ /^\s*\[assembly\]/) # must have a reference_point record
						fields = line.split("\t")
						# for adding chromsomes do:
						# Make a set of fdata/fgroup/fname for the chromosome, enter them into fdatatoc
						refName = fields[0].strip
						length = fields[2].strip.to_i
						tableDatatocIDs = self.makeTableSet(refName, typeID)
						# Make an fentrypoint record for the chromosome, use the fdatatoc_id for the fdata table
						entrypointID = @keywordUtil.getEntrypointID(refName)
						if(entrypointID.nil?)
							entrypointID = @keywordUtil.addEntrypointRecord(refName, nil, tableDatatocIDs[FDATA], nil)
						end
						# Make an entry in fdet for each table, using datatocs, typeID and entrypointID
						tableDatatocIDs.each {
							|datatocID|
							@keywordUtil.addDetRecord(datatocID, entrypointID, typeID)
						}
						# Recache the datatocs so we can get the table objs quickly
						@keywordUtil.recacheTableObjects()
						# Make an fname record for the chromosome if no record for this name already
						nameID = @keywordUtil.getNameID(entrypointID, typeID, refName)
						if(nameID.nil?)
							nameID = @keywordUtil.addNameRecord(entrypointID, typeID, refName)
						end
						# Make an fdata record for the chromosome, using entrypointID/typeID/fnameID
						# Unless we have one in there already *exactly* like this one.
						dataID = self.insertAsAnnotation(entrypointID, typeID, nameID, length)
						# Update the entrypoint record with the fdata_id
						@keywordUtil.updateEntrypointTable(entrypointID, dataID)
					elsif(state == ST_REF_POINTS and line =~ /^\s*\[assembly\]/)
						state = ST_END
					else
						raise(IOError, "\nERROR: bad LDAS header file #{fileName}. Parse error at line #{lineCount}.\n")
					end
				}
			ensure # must unlock the tables!
				lockReply = @keywordUtil.unlockDB()
				if(lockReply.nil?)
					raise(BRL::Keyword::KeywordDBError, "\nERROR: unlock SQL returned NULL, this is very bad since it indicates huge issue with database. Track this down!\n")
				elsif(lockReply == 0)
					raise(BRL::Keyword::KeywordDBError, "\nERROR: the shared lock wasn't set and so the release failed. Is all the locking stuff working or do you have a bug?!\n")
				end
			end
		end

		############
		protected
		############
		def insertAsAnnotation(entrypointID, typeID, nameID, length)
			start = 1
			stop = length
			dataTable = @keywordUtil.getTableObj(entrypointID, typeID, 'fdata')
			dataRecord = BRL::Keyword::Chr_type_fdata_TEMPLATEDBRecord.new(dataTable, @keywordUtil.dbh)
			dataRecord['fdata_id'] = nil
			dataRecord['fdata_start'] = start
			dataRecord['fdata_stop'] = stop
			dataRecord['fdata_bin'] = @keywordUtil.binCalc.bin(BRL::Keyword::MIN_BIN, start, stop)
			dataRecord['fdata_phase'] = nil
			dataRecord['fdata_score'] = 1.0
			dataRecord['fdata_target_start'] = nil
			dataRecord['fdata_target_stop'] = nil
			dataRecord['FK_fname_id'] = nameID
			dataRecord['FK_fentrypoint_id'] = entrypointID
			dataRecord['FK_ftype_id'] = typeID
			whereStr = "(FK_fentrypoint_id=#{entrypointID} AND fdata_bin=#{dataRecord['fdata_bin']} AND fdata_start=#{start} AND fdata_stop=#{stop} AND FK_ftype_id=#{typeID}) AND "
			whereStr << "FK_fname_id=#{nameID} AND fdata_score=1.0 AND fdata_phase IS NULL AND fdata_target_start IS NULL AND fdata_target_stop IS NULL "
			row = dataTable.select_one('fdata_id', whereStr)
			if(row.nil?) # insert the record
				dataTable.insert(dataRecord, true)
				dataID = @keywordUtil.dbh.func(:insert_id)
			else
				dataID = row[0]
			end
			return dataID
		end

		def makeTableSet(entrypointName, typeID)
			# generate table names for: fdata, fgroup, fname
			cleanEntrypointName = entrypointName.gsub(/[^A-Za-z0-9]/, '_')
			prefix = "#{cleanEntrypointName}_#{typeID}"
			dataTableName = "#{prefix}_fdata"
			groupTableName = "#{prefix}_fgroup"
			nameTableName = "#{prefix}_fname"
			# create each table (will only be created if doesn't exist already)
			BRL::Keyword::Chr_type_fdata_TEMPLATEDBTable.create(dataTableName, @keywordUtil.dbh)
			BRL::Keyword::Fgroup_TEMPLATEDBTable.create(groupTableName, @keywordUtil.dbh)
			BRL::Keyword::Fname_TEMPLATEDBTable.create(nameTableName, @keywordUtil.dbh)

			# Make the datatoc entries, if necessary; get datatocIDs
			dataTableTocID = @keywordUtil.getDatatocIDByName(dataTableName)
			if(dataTableTocID.nil?)
				dataTableTocID = @keywordUtil.addDatatocRecord(dataTableName, 'fdata')
			end

			groupTableTocID = @keywordUtil.getDatatocIDByName(groupTableName)
			if(groupTableTocID.nil?)
				groupTableTocID = @keywordUtil.addDatatocRecord(groupTableName, 'fgroup')
			end

			nameTableTocID = @keywordUtil.getDatatocIDByName(nameTableName)
			if(nameTableTocID.nil?)
				nameTableTocID = @keywordUtil.addDatatocRecord(nameTableName, 'fname')
			end

			return [ dataTableTocID, groupTableTocID, nameTableTocID ]
		end
	end # class KeywordLFFUtil
end ; end
