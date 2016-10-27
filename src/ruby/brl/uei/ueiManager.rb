#!/usr/bin/env ruby

# ##############################################################################
# REQUIRED LIBRARIES
# ##############################################################################
require 'brl/util/textFileUtil' # For TextReader/Writer convenience classes
require 'dbi'
require 'brl/db/dbrc'						# For brl/db/DBRC class and database nicities
require 'brl/db/util'
require 'brl/uei/ueiTables'
require 'bases'									# For any-base support
require 'socket'
# ##############################################################################
# Turn on extra warnings and such
$VERBOSE = true

module BRL ; module UEI

	class UEIError < StandardError ; end

	class UEIManager
		attr_accessor :dbRecord, :dbrc, :dbh, :ueiTable

		@@databaseName = 'andrewj_uei'

		def initialize(dbrcFile)
			@dbrc = BRL::DB::DBRC.new(dbrcFile, @@databaseName)
			@dbh = DBI.connect(dbrc.driver, dbrc.user, dbrc.password)
			@ueiTable = BRL::UEI::UEIDBTable.new(@dbh)
		end

# for date: DATE_FORMAT(dateColumn, "%d-%m-%Y %H:%i:%S")

		def getNewUEI(peerDomain='localhost')
			ueiArray = self.getNewUEIs(1, peerDomain)
			return ueiArray[0]
		end

		def getNewUEIs(numNewUEIs, peerDomain='localhost')
			# lock the table
			@ueiTable.writeLock()
			ueiIntStr = nil
			newUEIIntStrs = []
			newUEIChkSums = []
			valuesArray = []
			retArray = []
			begin # make sure we unlock the table, even if problem
				# get the last one inserted (max primary key)
				ueiIntStr,ueiChkSum = self.getLastUEIInserted()
				# increment the ueiInt numNewUEIs times and store in array
				# compute the new checksum numNewUEIs times and store in array
				# foreach new UEI, make a new hash keyed by columns and add each hash to a values array (use 'NOW()' for timestamp)
				# make array of strings for each uei using the ueiInt and checksum
				currUEIStr = ueiIntStr
				numNewUEIs.times {
					|ii|
					currUEIStr = self.incrementUEI(currUEIStr)
					newUEIIntStrs << currUEIStr
					newUEIChkSums << currUEIStr.sum(16)
					valuesArray << self.makeNewDBRecord(nil, currUEIStr, newUEIChkSums.last, Time.now(), peerDomain)
					retArray << (newUEIIntStrs.last + '-' + newUEIChkSums.last.to_base(36))
				}
				# get column names as an array
				colNames = @ueiTable.columnNames()
				# insert the values array as a batch insert
				@ueiTable.insertBatch(colNames, valuesArray)
			ensure
				# unlock the table
				@ueiTable.unlock()
			end
				# return it
				return retArray
		end

		def isUEIAssigned?(ueiStr)
			assignedHash = self.areUEIsAssigned([ ueiStr ])
			row = self.getTimeStampForUEI(ueiStr)
			# return t/f
			return (row.nil?() ? false : true)
		end

		def areUEIsAssigned?(ueiArray)
			assignedHash = self.getTimeStampsForUEIs(ueiArray)
			assignedHash.each {
				|ueiStr, timestamp|
				if(timestamp.nil?)
					assignedHash[ueiStr] = nil
				elsif(timestamp =~ /^00\-00\-0000 00\:00\:00$/)
					assignedHash[ueiStr] = false
				else
					assignedHash[ueiStr] = true
				end
			}
			return assignedHash
		end

		def getTimeStampsForUEIs(ueiArray)
			rows = nil
			retHash = {}
			ueiCount = 0
			# Lock the table
			@ueiTable.writeLock()
			begin
				# make where clause
				whereStr = 'ueiInt IN ('
				ueiArray.each {
					|ueiStr|
					# Does the ueiStr look valid?
					ueiIntStr, ueiChkSum = self.breakApartUEI(ueiStr)
					if(self.validateUEI(ueiStr))
						whereStr << "'#{ueiIntStr}',"
						ueiCount += 1
					else
						retHash[ueiStr] = nil # Can't tell, doesn't look like actual uei
					end
				}
				whereStr.chop!
				whereStr << ') '
				# do select if anything good given
				if(ueiCount > 0)
					rows = @ueiTable.select_all('CONCAT_WS("-", ueiInt, LOWER(CONV(ueiCheckSum, 10, 36))), DATE_FORMAT(timeStamp, "%d-%m-%Y %H:%i:%S")', whereStr)
				end
			ensure
				# unlock table
				@ueiTable.unlock()
			end
			# return as hash, keyed by uei (with nil meaning 'cant tell')
			unless(rows.nil?)
				rows.each {
					|row|
					retHash[row[0]] = row[1]
				}
			end
			# For each uei in ueiArray that no timestamp was found, put 0-time to indicate never assigned
			# Note, all will be value ueis at this point, because invalid ones got nil time.
			ueiArray.each {
				|ueiStr|
				unless(retHash.key?(ueiStr))
					retHash[ueiStr] = '00-00-0000 00:00:00'
				end
			}
			return retHash
		end

		def getTimeStampForUEI(ueiStr)
			timestampHashArray = self.getTimeStampsForUEIs([ ueiStr ])
			return timestampHashArray[0][ueiStr]
		end

		###############
		protected
		###############
		def makeNewDBRecord(id, ueiIntStr, chkSumStr, timeStamp, peerDomain)
			dbRecord = BRL::UEI::UEIDBRecord.new(@dbh)
			# fill in the hash fields with new values, including 'NOW()' for timestamp
			dbRecord['id'] = id
			dbRecord['ueiInt'] = ueiIntStr
			dbRecord['ueiCheckSum'] = chkSumStr
			dbRecord['timeStamp'] = timeStamp
			dbRecord['ipAddress'] = IPSocket.getaddress(peerDomain)
			return dbRecord
		end

		def incrementUEI(ueiIntStr)
			ueiInt = ueiIntStr.to_i(36)
			ueiInt += 1
			ueiIntStr = ueiInt.to_base(36)
			return ueiIntStr
		end

		def getLastUEIInserted()
			# get the last one inserted (max primary key)
			whatStr = 'ueiInt, ueiCheckSum'
			ordGrpStr = 'ORDER BY id DESC LIMIT 1'
			row = @ueiTable.select_one(whatStr,nil,ordGrpStr)
			return [ row[0], row[1] ]
		end

		def validateUEI(uei, checkSum=nil)
			uei = uei.strip
			# if no checksum, break it apart first
			ueiIntStr, ueiChkSum = nil
			if(checkSum.nil?)
				ueiIntStr, ueiChkSum = self.breakApartUEI(uei)
			else
				ueiIntStr = uei
			end
			# check int part valid
			unless(ueiIntStr =~ /^[a-zA-Z0-9]+$/)
				return false
			end
			# then verify check sum ok
			unless(ueiIntStr.sum(16) == ueiChkSum.to_i(36))
				return false
			end
			# everything looks ok
			return true
		end

		def breakApartUEI(ueiStr)
			ueiStr = ueiStr.strip
			# check if ueiStr is actually a uri string
			if(ueiStr =~ /^uei:/)
				#    if so, dig out terminal uei
				ueiStr = ueiStr.split(':').last.split('/').last
			end
			# may need to merge dashed uei str parts to make proper int
			ueiStr.delete!('-')
			# last 2 bytes must be check sum
			ueiChkSum = ueiStr.slice!(-2, 2)
			return [ueiStr, ueiChkSum]
		end
	end # class UEIManager
end ; end
        
