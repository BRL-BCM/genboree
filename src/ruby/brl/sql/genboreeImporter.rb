#!/usr/bin/env ruby
$VERBOSE = 1

=begin
This file implements the class GenboreeImporter within the *BRL::SQL* module.

*GenboreeImporter* takes a LFF input file and imports it to the Genboree database.

*GenboreeImporter* has three settable properties:
	dbrcFile - The location of a dbrc file containing login information for the database.
	outputDB - The name of the Genboree database.
	logFiles - The location to place log files of imported files.

*GenboreeImporter* has one method:
	lffFile - Imports the LFF file to Genboree.
		Arguments:
		inputFile - The location of the LFF file.
		styleId - The style id to be placed in Genboree.  The default is 1.
		delete - Deletes the current database records if true is passed.  False is the
			default.

*GenboreeImporter* can be called from the command line with the following options:
	-h     This help message.
	-l     Passes the parameter to lffFile which imports the LFF file
	       given into Genboree.
	-d    OPTIONAL If supplied this deletes the current records from
	       Genboree if true is passed and does not delete the records if
	       false is passed.  The default is false.

Author: Alan Harris <rharris1@bcm.tmc.edu>
Date  : March 13, 2003
=end

require 'dbi'
require "brl/db/dbrc"
require "binning"
require 'brl/util/textFileUtil'

module BRL; module SQL

class GenboreeImporter

	attr_accessor :dbrcFile, :outputDB, :logFiles

	def initialize
		@dbrcFile = "/users/hgsc/rharris1/.dbrc.rharris1"
		@outputDB = "genboree"
		@logFiles = "/users/hgsc/rharris1/work/brl-depot/rharris1/logs/"
	end

	def lffFile(inputFile,styleId=1,delete=false)

		#Log file
		writer = BRL::Util::TextWriter.new(@logFiles + File.basename(inputFile) + ".log", false)

		if (FileTest.exists?(inputFile))
			#Open file for reading
			reader = BRL::Util::TextReader.new(inputFile)
		else
			writer.write("ERROR: File #{inputFile} does not exist.\n")
			raise "\nERROR: File #{inputFile} does not exist.\n"
		end

		#Output Database connection
		dbrc = BRL::DB::DBRC.new(dbrcFile,outputDB)
          # WRONG!
          # Must use brl/genboree/dbUtil to connect to genboree
          # This will (a) not work anyway in this case and (b) runs the risk of
          # breaking in the multi-db-machine scenario we are using.
          # DbUtil is aware of multi-db-machine possibility and also does some connection caching as well.
		outputDbh = DBI.connect(dbrc.driver,dbrc.user,dbrc.password I_AM_BROKEN_FOR_GENBOREE_DATABSE_HANDLES)

		#Lock output tables
		sql = "LOCK TABLES ftype WRITE, fgroup WRITE, fdata WRITE"
		outputDbh.execute(sql)

		if(delete==true)
			sql = "DELETE FROM ftype"
			outtputDbh.execute(sql)

			sql = "DELETE FROM fgroup"
			outputDbh.execute(sql)

			sql = "DELETE FROM fdata"
			outputDbh.execute(sql)
		end

		sql = "INSERT INTO fgroup(gclass,gname) VALUES (?,?)"
		fgroupSql = outputDbh.prepare(sql)

		sql = "INSERT INTO ftype(fmethod,fsource) VALUES (?,?)"
		ftypeSql = outputDbh.prepare(sql)

		sql = "INSERT INTO fdata(fref,fstart,fstop,fbin,ftypeid,fscore,fstrand,fphase,gid,ftarget_start,ftarget_stop) VALUES (?,?,?,?,?,?,?,?,?,?,?)"
		fdataSql = outputDbh.prepare(sql)

		#Genobree main database connection
		dbrc = BRL::DB::DBRC.new(dbrcFile,"genboreeMain")
		genboreeDbh = DBI.connect(dbrc.driver,dbrc.user,dbrc.password)

		sql = "INSERT INTO featuretype (name) VALUES (?)"
		featuretypeSql = genboreeDbh.prepare(sql)

		sql = "INSERT INTO defaultuserfeaturetypestyle (featureTypeId, styleId) VALUES (?,?)"
		defaultuserfeaturetypestyleSql = genboreeDbh.prepare(sql)

		#Instantiate binning object
		binning = BRL::SQL::Binning.new()

		insertId = ""
		annotationTypeHash = Hash.new
		annotationGroupHash = Hash.new
		lineArray = Array.new

		#Variables for reference
		seenRefType = false

		#Hash for name
		nameHash = Hash.new

		reader.each do
			| line |

			unless(line =~ /^\s*$/ || line =~ /^\s*#/ || line =~ /^\s*\[/ || lineArray.include?(line))

				lineArray.push(line)

				arrSplit = line.split(/\s+/)

				#Reference
				if(arrSplit.length==3)
					#-----Insert into ftype------
					if(seenRefType==false)
						ftypeSql.execute("Component","Chromosome")
						@componentId = outputDbh.func("insert_id")

						ftypeSql.execute("Supercomponent","Sequence")
						@superComponentId = outputDbh.func("insert_id")

						seenRefType = true
					end

					#-----Insert into fgroup------
					fgroupSql.execute(arrSplit[1],arrSplit[0])
					insertId = outputDbh.func("insert_id")

					#-----Insert into fdata------
					stop = arrSplit[2].to_i - 1
					bin = binning.bin(1000,1,stop)
					fdataSql.execute(arrSplit[0],1,stop,bin,@componentId,0,"+",".",insertId,1,stop)
					fdataSql.execute(arrSplit[0],1,stop,bin,@superComponentId,0,"+",".",insertId,1,stop)

				#Assembly
				elsif(arrSplit.length==7)

				#Annotation
				elsif(arrSplit.length==10 || arrSplit.length==12)
					#-----Insert into ftype------
					type = arrSplit[2] + ":" + arrSplit[3]
					if (annotationTypeHash.include?(type))
						typeId = annotationTypeHash.fetch(type)
					else
						ftypeSql.execute(arrSplit[2],arrSplit[3])
						typeId = outputDbh.func("insert_id")

						#Check for type in featuretype main genboree db
						sql = "SELECT * FROM featuretype WHERE name = '#{type}'"
						record = genboreeDbh.select_one(sql)
						if(record==nil)
								#Inserts into main genboree db
								#featuretypeSql.execute(type)
								#insertId = genboreeDbh.func("insert_id")
						else
								insertId = record[0]
						end

						#TO DO:  Set public/private user style types
						#defaultuserfeaturetypestyleSql.execute(insertId,styleId)

						annotationTypeHash[type] = typeId
					end

					#-----Insert into fgroup------
					#Check for duplicate name
					name = arrSplit[1]
					nameDowncase = name.downcase
					if (nameHash.has_key?(nameDowncase))
						count = nameHash.fetch(nameDowncase)
						count = count + 1
						nameHash[nameDowncase] = count
						name = name + "." + count.to_s
					else
						nameHash[nameDowncase] = 0
					end

					group = arrSplit[0] + ":" + name
					if (annotationGroupHash.include?(group))
						groupId = annotationGroupHash.fetch(group)
					else
						fgroupSql.execute(arrSplit[0],name)
						groupId = outputDbh.func("insert_id")

						annotationGroupHash[group] = groupId
					end

					#-----Insert into fdata------
					bin = binning.bin(1000,arrSplit[5],arrSplit[6])
					fdataSql.execute(arrSplit[4],arrSplit[5],arrSplit[6],bin,typeId,arrSplit[9],arrSplit[7],arrSplit[8],groupId,arrSplit[10],arrSplit[11])
				else
					writer.write("ERROR: Incorrect number of columns in LFF file\n")
					raise "\nERROR: Incorrect number of columns in LFF file\n"
				end
			end
		end

		outputDbh.execute("UNLOCK TABLES")
		outputDbh.disconnect
	end

end #GenboreeImporter

end; end #module BRL; module SQL

unless (ARGV.empty?)
	if(ARGV.include?"-h")
		puts "The following commands are available to GenboreeImporter:\n\n"
		puts "-h     This help message.\n"
		puts "-l     Passes the parameter to lffFile which imports the LFF file\n"
		puts "       given into Genboree.\n"
		puts "-d     OPTIONAL If supplied this deletes the current records from\n"
		puts "       Genboree if true is passed and does not delete the records if\n"
		puts "       false is passed.  The default is false.\n"
	elsif(ARGV.include?"-l")
		switch = ARGV.index("-l")
		file = ARGV.at(switch + 1)
		if ARGV.include?("-d")
			switch = ARGV.index("-d")
			delete = ARGV.at(switch + 1)
			puts delete
		else
			delete = false
		end

		importer = BRL::SQL::GenboreeImporter.new
		importer.lffFile(file,1,eval(delete))
	else
		raise "\nIncorrect argument to GenboreeImporter\n"
	end
end
