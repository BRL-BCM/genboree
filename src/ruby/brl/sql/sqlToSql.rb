
#!/usr/bin/env ruby
$VERBOSE = true

=begin
This file implements the class SqlToSql within the *BRL::SQL* module.

*SqlToSql* is a database independent interface to migrate data from one database to another.  Specific
information for migrating tables from the UCSC database to the Genboree database is implemented in a separate
class called UcscSqlExporter.

*SqlToSql* is initialized with a definition source that can be a file, string or standard IO.  The
definition source contains information to map fields from the input table to the output table.  Currently two
mappings are available that use three different operators.  The definition source has a required header and
can include comments on lines starting with #.  The following is an example:

#Comment line
Source Op Dest - This is the required header
sourceTableField -> destinationTableField
"Constant" constant destinationTableField

The -> operator is used for direct mapping of one field to another.  The constant operator allows the
placement of a constant in the destination field.

*SqlToSql* is initialized with the following additional arguments:
	style - The style id to be placed in Genboree.  The default is 1.
	refPrefix - A prefix to appended to the reference chromosome.  The default is "".
	idHash - A hash containing record id information.
	idHashName - The name of the idHash.

The method *output* takes the following arguments:
	dbrcFilename - The location of a dbrc file containing login information for the database.
	inputDatabase - The source database to be used as named in the dbrc file.
	inputTable - The table within the source database from which the data is to exported.
	outputDatabase - The destination database to be used as named in the dbrc file.
	outputTable - The table within the destination database to which the data is imported.
	chromField - The name of the field in the database containing the chromosome.
	nameField - The name of the field in the database containing the reference name.
	blockCountField - The name of the field in the database containing the number of blocks represented
	      by the record.  If this argument is not supplied the record is considered a single block.
	blockStartField - The name of the field in the database containing the block start positions.
	blockEndField - The name of the field in the database containing the block end positions.
	targetStartField- The name of the field in the database containing the target start positions.
	targetEndField - The name of the field in the database containing the target end positions.
	blockIsLength - Set to false if the block end is the actual end position of the block.
		Set to true if the block end is the length of the block.

*SqlToSqlError* is a class used for error handling that inherits from the StandardError object.

Author: Alan Harris <rharris1@bcm.tmc.edu>
Date  : March 13, 2003
=end

require 'dbi'
require "brl/db/dbrc"
require "binning"
require 'brl/util/textFileUtil'

module BRL; module SQL

#--------------------------------------------------------------------------------------------------------
#Class :  sqlToSql
#Input :  definitionSrc = Information to map one object to a second object.
#Usage :  sqlToSql.new(definitionSrc)
#--------------------------------------------------------------------------------------------------------
	class SqlToSql

		def initialize(definitionSrc,style=1,refPrefix="",idHash=nil,idHashName=nil)
			# First, check that we can read the mapping info from the source
			# Allows reading from Files, TextReaders, Arrays, Strings, Sockets, other IOs, etc
			unless(definitionSrc.respond_to?('each'))
				raise(sqlToSqlError, "\nERROR: the argument to SqlToSql.new() must respond to the 'each' method!\n")
			end

			#Hash for geneName
			@nameHash = Hash.new

			@refPrefix = refPrefix
			@idHash = idHash
			@idHashName = idHashName
			@style = style

			# Parse definition info
			@inputField = []
			@operator = []
			@outputField = []
			@outputString = ""
			@blankValues = ""
			#Used to determine if all the inputs are constants
			@useInputDB = false

			seenHeader = false
			lineNum = 0

			definitionSrc.each {
				|line|
				next if(line =~ /^\s*$/ || line =~ /^\s*#/) # skip blank/empty lines or comments
				# Check for header line, if we haven't seen it yet
				unless(seenHeader)
					if(line =~ /^Source/) # then is ok header line
						seenHeader = true
						lineNum+= 1
						next
					else # bad header or no header! Raise appropriate error classs...here, StandardError
						raise "\nERROR: no header line! Error at line #{lineNum}\n"
					end
				end

				# Ok, we have a real line, PARSE LINE
				if(line =~ /^\s*(\"[^\"]+\")\s+(constant)\s+(\w+)\s*$/) # then we have "constant" op line
					# no-op, just need the $1, $2, $3 set...
				elsif(line =~ /^\s*(\w+)\s+(->)\s+(\w+)\s*$/) # then we have a "->" op line
					# no-op, just need the $1, $2, $3 set...
				elsif(line =~ /^\s*(\w+)\s+(regexp:\".+\")\s+(\w+)\s*$/) # then we have a "regexp:" op line
					# no-op, just need the $1, $2, $3 set...
				else # unknown op line! raise appropriate error class
					raise(SqlToSqlError,  "\nERROR: bad operation format line at #{lineNum}\n\n")
				end
				input = $1.strip
				input.delete! '"'
				@inputField.push(input)
				@operator.push($2.strip)
				@outputField.push($3.strip)

				#Create strings needed for SQL from the mapping
				if($2 == "->")
					@useInputDB = true
				end

				@outputString = @outputString + $3 + ","
				@blankValues = @blankValues + "?,"

				lineNum+= 1
			}

			#Chomp final "," off strings
			@outputString.chomp!(",")
			@blankValues.chomp!(",")
		end #def initialize

		def output(dbrcFilename, inputDatabase, inputTable, outputDatabase, outputTable, chromField=nil, nameField=nil, blockCountField=nil,blockStartField=nil,blockEndField=nil,targetStartField=nil,targetEndField=nil,blockIsLength=false)

			#Output Database connection
			dbrc = BRL::DB::DBRC.new(dbrcFilename,outputDatabase)
			outputDbh = DBI.connect(dbrc.driver,dbrc.user,dbrc.password)

			#Lock output table
			sql = "LOCK TABLES #{outputTable} WRITE"
			outputDbh.execute(sql)


			if (@useInputDB == true)
				insertId = Hash.new

				#Instantiate binning object
				binning = BRL::SQL::Binning.new()

				#Log file
				writer = BRL::Util::TextWriter.new("./logs/" + inputTable + ".log", false)

				#Input Database connection
				dbrc = BRL::DB::DBRC.new(dbrcFilename,inputDatabase)
				inputDbh = DBI.connect(dbrc.driver,dbrc.user,dbrc.password)

				#Prepare SQL INSERT statement
				sql = "INSERT INTO #{outputTable} (#{@outputString}) VALUES (#{@blankValues})"
				sth = outputDbh.prepare(sql)
				puts sql

				#Lock input table
				sql = "LOCK TABLES #{inputTable} WRITE"
				inputDbh.execute(sql)

				#Open recordset
				sql = "SELECT * FROM " + inputTable

				# If each row is considered a record
				if (blockCountField == nil)
					inputDbh.select_all(sql) do
						| row |

						#Check for alternate splicing
						unless (nameField == nil)
							name = row[nameField]
							nameDowncase = name.downcase

							if (@nameHash.has_key?(nameDowncase))
								spliceCount = @nameHash.fetch(nameDowncase)
								spliceCount = spliceCount + 1
								@nameHash[nameDowncase] = spliceCount
								name = name + "." + spliceCount.to_s
							else
								@nameHash[nameDowncase] = 0
							end
						end

						values = []

						@inputField.each_index{
							|index|
							if(@operator[index] == 'constant')
								values.push(@inputField[index])
							elsif(@operator[index] == '->')
								if(@inputField[index]  == nameField)
									values.push(name)
								else
									field = @inputField[index]
									values.push(row[field].to_s)
								end
							elsif(@operator[index] =~ /^regexp:/)
								# trickier!!! because of multiple group possibilities with | separating.
								# We will be ~smart...the rule is that we take the first *matching* group
								# First, we need out regexp without the regexp: string in front and with quotes
								@operator[index] =~ /^regexp:\"(.+)\"$/
								reStr = $1
								#evalStr = "row.#{@outputField[index]} = Regexp.new('#{reStr}').match(inputObject.#{@inputField[index]}).to_a.compact[1]"
								#eval(evalStr)
								#line = line + row.@inputField[index] + "/t"
							else # unknown op line! raise appropriate error class
								raise(sqlToSqlError, "\nERROR: bad operator\n\n")
							end
						}

						#Check that all fields are populated
						fieldsPopulated = true
						values.each {
							|value|
							value.to_s.strip!
							if(value == "")
								fieldsPopulated = false
							end
						}

						if (fieldsPopulated == true)
							#Execute SQL insert passing values
							sth.execute(*values)

							#Find the id of the inserted record
							insertId[name] = outputDbh.func("insert_id")
						else
							line = row.to_a.join(",")
							writer.write(line + "\n")
						end
					end
				# If the blocks in each row are considered a record
				else
					inputDbh.select_all(sql) do
						| row |
						#Exclude chrN_random records
						unless (row[chromField] =~ /\w*_random/)

							#Check for alternate splicing
							unless (nameField == nil)
								name = row[nameField]
								nameDowncase = name.downcase
								if (@nameHash.include?(nameDowncase))
									spliceCount = @nameHash.fetch(nameDowncase)
									spliceCount = spliceCount + 1
									@nameHash[nameDowncase] = spliceCount
									name = name + "." + spliceCount.to_s
								else
									@nameHash[nameDowncase] = 0
								end
							end

							blocks = row[blockCountField] - 1
							blockCount = 0

							blockStartArr = row[blockStartField].split(/,/)
							blockEndArr = row[blockEndField].split(/,/)

							unless (targetStartField == nil)
								targetStartArr = row[targetStartField].split(/,/)
								targetEndArr = row[targetEndField].split(/,/)
							end

							#Add a record for each block
							while (blockCount <= blocks) do
								blockStart = blockStartArr[blockCount].to_i + 1
								unless (targetStartField == nil)
									targetStart = targetStartArr[blockCount].to_i + 1
								end
								#Different schema give the block end postion either as the actual end position or the start and the length
								if (blockIsLength == true)
									blockEnd = blockStartArr[blockCount].to_i + blockEndArr[blockCount].to_i
									unless(targetStartField == nil)
										targetEnd = targetStartArr[blockCount].to_i + targetEndArr[blockCount].to_i
									end
								else
									blockEnd = blockEndArr[blockCount]
									unless(targetStartField == nil)
										targetEnd = targetEndArr[blockCount]
									end
								end

								#Fix for using the block size field for both block and target end when the end position is given as the length
								seenBlockEnd = false

								values = []

								@inputField.each_index{
									|index|
									if(@operator[index] == 'constant')
										if(@inputField[index] == @idHashName)
											if @idHash.has_key?(name)
													id = @idHash.fetch(name)
												  values.push(id)
											end
										else
											values.push(@inputField[index])
										end
									elsif(@operator[index] == '->')
										if (@inputField[index]  == blockStartField)
											values.push(blockStart.to_s)
										elsif(@inputField[index]  == blockEndField) && (seenBlockEnd == false)
											values.push(blockEnd.to_s)
											seenBlockEnd = true
										elsif(@inputField[index] == nameField)
											values.push(name)
										elsif(@inputField[index] == targetStartField)
											values.push(targetStart.to_s)
										elsif(@inputField[index] == targetEndField)
											values.push(targetEnd.to_s)
										elsif(@inputField[index] == "fbin")
											#Calculate fbin value
											binValue = binning.bin(1000,blockStart,blockEnd)
											values.push(binValue.to_s)
										elsif(@inputField[index] == chromField)
											field = @inputField[index]
											chrom = row[field].capitalize
											chrom.gsub!(/x/,'X')
											chrom.gsub!(/y/,'Y')
											values.push(@refPrefix + chrom)
										else
											field = @inputField[index]
											values.push(row[field].to_s)
										end
									elsif(@operator[index] =~ /^regexp:/)
										# trickier!!! because of multiple group possibilities with | separating.
										# We will be ~smart...the rule is that we take the first *matching* group
										# First, we need out regexp without the regexp: string in front and with quotes
										@operator[index] =~ /^regexp:\"(.+)\"$/
										reStr = $1
										#evalStr = "row.#{@outputField[index]} = Regexp.new('#{reStr}').match(inputObject.#{@inputField[index]}).to_a.compact[1]"
										#eval(evalStr)
										#values = values + row.@inputField[index] + "/t"
									else # unknown op line! raise appropriate error class
										raise(sqlToSqlError, "\nERROR: bad operator\n\n")
									end
								}

								#Check that all fields are populated
								fieldsPopulated = true
								values.each {
									|value|
									value.to_s.strip!
									if(value == "")
										fieldsPopulated = false
									end
								}

								if (fieldsPopulated == true)
									#Execute SQL insert passing values
									sth.execute(*values)

									#Find the id of the inserted record
									insertId[name] = outputDbh.func("insert_id")
								else
									line = row.to_a.join(",")
									writer.write(line + "\n")
								end

								blockCount = blockCount + 1
							end
						end
					end
				end


				sql = "UNLOCK TABLES"
				inputDbh.execute(sql)
				inputDbh.disconnect

			else	# (@useInputDB = false) Only constants are loaded into outputDB
				insertId = ""

				#Prepare SQL INSERT statement
				sql = "INSERT INTO #{outputTable} (#{@outputString}) VALUES (#{@blankValues})"
				sth = outputDbh.prepare(sql)
				puts sql

				#Execute SQL insert passing values as
				sth.execute(*@inputField)

				#Find the id of the inserted record
				insertId = outputDbh.func("insert_id")

				#SQL for inserting name into main genoboree feature type table
				sql = "INSERT INTO featuretype (name) VALUES ('#{@inputField.join(':')}')"

				#Genobree main database connection
				# WRONG!
          # Must use brl/genboree/dbUtil to connect to genboree
          # This will (a) not work anyway in this case and (b) runs the risk of
          # breaking in the multi-db-machine scenario we are using.
          # DbUtil is aware of multi-db-machine possibility and also does some connection caching as well.
				dbrc = BRL::DB::DBRC.new(dbrcFilename,"genboreeMain" I_AM_BROKEN_FOR_GENBOREE_DATABSE_HANDLES)
				genboreeDbh = DBI.connect(dbrc.driver,dbrc.user,dbrc.password)

				genboreeDbh.execute(sql)

				#Find the id of the inserted record
				featureTypeId = genboreeDbh.func("insert_id")

				sql = "INSERT INTO defaultuserfeaturetypestyle (featureTypeId, styleId) VALUES (#{featureTypeId},#{@style})"

				genboreeDbh.execute(sql)

				genboreeDbh.disconnect

			end

			sql = "UNLOCK TABLES"
			outputDbh.execute(sql)
			outputDbh.disconnect
			output = insertId
		end #def output

	end #class sqlToSql

#--------------------------------------------------------------------------------------------------------
#Class :  sqlToSqlError
#Input :  Error message to be displayed to user.
#Output:  Outputs to StandardError.
#Usage :  raise(sqlToSqlError, "Error Message")
#--------------------------------------------------------------------------------------------------------
	class SqlToSqlError < StandardError ; end

end; end #module BRL; module sqlToSql
