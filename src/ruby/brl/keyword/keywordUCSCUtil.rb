#!/usr/bin/env ruby

# ##############################################################################
# REQUIRED LIBRARIES
# ##############################################################################
require 'brl/util/textFileUtil' # For TextReader/Writer convenience classes
require 'dbi'
require 'brl/db/dbrc' # For brl/db/DBRC class and database nicities
require 'brl/db/util'
require 'brl/keyword/keywordTables'
require 'brl/keyword/keywordDBUtil'
# ##############################################################################
# Turn on extra warnings and such
$VERBOSE = true

module BRL ; module Keyword
class KeywordLFFUtil
attr_reader :keywordUtil

def initialize(dbrcFile)
@keywordUtil = BRL::Keyword::KeywordDBUtil.new(dbrcFile)
end

def importFromLFFFile(fileName, typeRecordsHash)
# go through line-by-line
lffFile = File.open(fileName)
lffFile.each {
line
# split the line
fields = line.split("\t")
# check if there is an entrypoint with this fentrypoint_name (must already exist)
entrypointID = self.getEntrypointID(fields[2])
if(entrypointID.nil?)
raise(BRL::Keyword::KeywordDBError, "\nERROR: #{fields[2]} is not an entrypoint in this database\n")
end
# check if class:name is an fdata with ftype of group:class already, else create group
groupTypeID = self.getGroupTypeID(fields[0])
groupDataID = nil
unless(groupTypeID.nil?())
# First, get name entry for this group
row = nameTable.select_one('fname_id', "fname_value='#{fields[1]}'")
unless(row.nil?) # The group's name is in there, let's see if the data entry is in there
groupDataID = self.getGroupDataID(entrypointID, groupTypeID, row[0])
# do we need to update the group with new start/stop info?
self.updateGroupData(fields, entrypointID, groupTypeID, groupDataID, row[0])
end
end
# Did we manage to get the groupDataID or not?
if(groupDataID.nil?) # nope, need to make it
groupDataID = self.createNewGroup(entrypointID, fields, groupTypeID)
end
# Now insert the new annotation record
# check if type:subtype is a valid type record
dataTypeID = self.getDataTypeID(fields[2], fields[3])
dataID = self.insertAnnotation(fields, entrypointID, groupDataID, dataTypeID)
# Add a "member" entry to fgroup so we know this is a member of the group
self.addGroupMember(groupDataID, dataID, 1.0, entrypointID, dataTypeID)
}
end

def insertAnnotation(fields, entrypointID, typeID)
valArray = []
# fdata_id
valArray[0] = nil
# fdata_start, fdata_stop
valArray[1], valArray[2] = fields[5].to_i, fields[6].to_i
# fdata_bin
valArray[3] = keywordUtil.binCalc.bin(BRL::Keyword::MIN_BIN, fields[5], fields[6])
# fdata_phase
valArray[4] = (fields[8] == '.') ? nil : fields[8]
# fdata_score, fdata_strand
valArray[5], valArray[6] = fields[9].to_f, fields[7]
# fdata_target_start, fdata_target_stop
if(fields.length > 10)
valArray[7], valArray[8] = fields[10].to_i, fields[11].to_i
else
valArray[7], valArray[8] = nil, nil
end
# G_upload_id, FK_fname_id
valArray[9], valArray[10] = nil, nil
# FK_ftype_id, FK_entrypoint_id
valArray[11], valArray[12] = typeID, entrypointID

# Do insert
dataTableName = self.getTableName(entrypointID, typeID, 'fdata')
dataTable = BRL::Keyword::Chr_type_fdata_TEMPLATEDBTable.new(dataTableName, @keywordUtil.dbh)
dataTable.insert(valArray, true)
dataID = @keywordUtil.dbh.func('insert_id()')
return dataID.to_i
end

def updateGroupData(fields, entrypointID, typeID, groupDataID, name)
# What datatable?
dataTableName = self.getTableName(entrypointID, typeID, 'fdata')
dataTable = BRL::Keyword::Chr_type_fdata_TEMPLATEDBTable.new(dataTableName, @keywordUtil.dbh)
# Select current record for group ID
row = dataTable.select_one('*', "fdata_id=#{groupDataID}")
# If oldStart > start and/or oldStop< stop, set newstart & newstop appropriately using an update
newVals = {}
newVals['fdata_start'] = (fields[5] < row[1]) ? fields[5].to_i : row[1]
newVals['fdata_stop'] = (fields[6] > row[2]) ? fields[6].to_i : row[2]
if(fields.length <= 10)
newVals['fdata_target_start'] = row[7]
newVals['fdata_target_stop'] = row[8]
else
newVals['fdata_target_start'] = (fields[10] < row[7]) ? fields[10].to_i : row[7]
newVals['fdata_target_stop'] = (fields[11] > row[8]) ? fields[11].to_i : row[8]
end
if( (fields[5] < row[1]) or (fields[6] > row[2]) or (fields[10] < row[7]) or (fields[11] > row[8]) )
dataTable.update(newVals, "fdata_id=#{groupDataID}")
end
end

def getGroupDataID(entrypointID, typeID, name)
row = self.getGroupDataRecord(entrypointID, typeID, name)
return row.nil?() ? nil : row[0].to_i
end

def getGroupTypeID(class)
type = BRL::Keyword::KeywordDBUtil.DEF_GROUP_TYPE
typeTable = @keywordUtil.typeTable.new(@keywordUtil.dbh)
row = typeTable.select_one('fentrypoint_id', "ftype_type='#{type}' AND ftype_subtype='#{class}'")
return row.nil?() ? nil : row[0].to_i
end

def getDataTypeID(type, subtype)
row = @keywordUtil.typeTable.select_one('ftype_id', "ftype_type='#{type}' AND ftype_subtype='#{subtype}'")
return row.nil?() ? nil : row[0].to_i
end

def createNewGroup(lffFields, entrypointID, typeID)
# insert a new type into ftype table?
if(typeID.nil?())
@keywordUtil.typeTable.insert( [ nil, DEF_GROUP_TYPE, lffFields[0]], true )
typeID = @dbh.func('insert_id()')
end
# need a new fname entry also
@keywordUtil.nameTable.insert( [ nil, lffFields[1] ], true )
nameID = @keywordUtil.dbh.func('insert_id())')
# need a new fdata for the group, but we have to find the right table first
dataTableName = self.getTableName(entrypointID, typeID, 'fdata')
dataTable = BRL::Keyword::Chr_type_fdata_TEMPLATEDBTable.new(dataTableName, @keywordUtil.dbh)
if(lffFields.length > 10)
tstart = lffFields[10].to_i
tstop = lffFields[11].to_i
else
tstart = nil
tstop = nil
end
dataTable.insert( [ nil, lffFields[5].to_i, lffFields[6].to_i, @keywordUtil.binCalc.bin(BRL::Keyword::MIN_BIN, lffFields[5], lffFields[6]), lffFields[8], lffFields[9].to_i, lffFields[7], tstart, tstop, nameID, typeID, entrypointID ], true)
groupDataID = @keywordUtil.dbh.func('insert_id()')
return groupDataID
end
end # class KeywordLFFUtil
end ; end