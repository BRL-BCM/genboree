#!/usr/bin/env ruby
$VERBOSE = true

=begin
This file implements the class SqlToFile within the *BRL::SQL* module.

*SqlToFile* is a database independent interface to output data from a table to a file.  Specific
information for outputting tables from the UCSC database is implemented in a separate class 
called UcscExporter.

*SqlToFile* is initialized with a definition source that can be a file, string or standard IO.  The 
definition source contains information to map database fields to a text file output.  Currently two
mappings are available that use three different operators.  The definition source has a required header and
can include comments on lines starting with #.  The following is an example:

#Comment line
Source Op Dest - This is the required header
sourceTableField -> destinationTextField
"Constant" constant destinationTextField

The -> operator is used for direct mapping of one field to another.  The constant operator allows the 
placement of a constant in the destination field.  

The method *output* takes the following arguments:
	dbrcFilename - The location of a dbrc file containing login information for the database.
	database - The database to be used as named in the dbrc file.
	table - The table within the database from which the data is to exported.
	outputFile - The name of the output file.
	doGzip - Gzip the output file.  True or false.
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

*SqlToFileError* is a class used for error handling that inherits from the StandardError object.

Author: Alan Harris <rharris1@bcm.tmc.edu>
Date  : March 13, 2003
=end

require 'brl/util/textFileUtil'
require 'dbi'
require "brl/db/dbrc"

module BRL; module SQL

#--------------------------------------------------------------------------------------------------------
#Class :  SqlToFile
#Input :  definitionSrc = Information to map a database to a output file.        
#Usage :  SqlToFile.new(definitionSrc)
#--------------------------------------------------------------------------------------------------------
	class SqlToFile

		def initialize(definitionSrc)
			# First, check that we can read the mapping info from the source
			# Allows reading from Files, TextReaders, Arrays, Strings, Sockets, other IOs, etc
			unless(definitionSrc.respond_to?('each'))
				raise(SqlToFileError, "\nERROR: the argument to SqlToFile.new() must respond to the 'each' method!\n")
			end

			# Parse definition info
			@inputField = []
			@operator = []
			@outputField = []
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
					raise(SqlToFileError,  "\nERROR: bad operation format line at #{lineNum}\n\n")
				end
				input = $1.strip
				input.delete! '"'
				@inputField.push(input)
				@operator.push($2.strip)
				@outputField.push($3.strip)
				lineNum+= 1
			}							
		end #def initialize

		def output(dbrcFilename,database,table,outputFile,doGzip,chromField=nil,nameField=nil,blockCountField=nil,blockStartField=nil,blockEndField=nil,targetStartField=nil,targetEndField=nil,blockIsLength=false)			
			
			if(outputFile != nil)
				writer = BRL::Util::TextWriter.new(outputFile, doGzip)
				line = ""
			
				#Database connection
				dbrc = BRL::DB::DBRC.new(dbrcFilename,database)
        			dbh = DBI.connect(dbrc.driver,dbrc.user,dbrc.password)

				#Open recordset
				sql = 'select * from ' + table
				#sth = dbh.prepare(sql)
				#sth.execute do
				
				#Hash for geneName
				nameHash = Hash.new
								
				# If each row is considered a record
				if (blockCountField == nil)
					dbh.select_all(sql) do 
						| row |
						
						#Check for alternate splicing
						name = row[nameField]
						if (nameHash.has_key?(name))
							spliceCount = nameHash.fetch(name)
							spliceCount = spliceCount + 1
							nameHash[name] = spliceCount
							name = name + "." + spliceCount.to_s
						else
							nameHash[name] = 0
						end
						
						@inputField.each_index{
							|index|
							if(@operator[index] == 'constant')
								line = line + @inputField[index] + "\t"
							elsif(@operator[index] == '->')
								if(@inputField[index]  == nameField)
									line = line + name + "\t"
								else
									field = @inputField[index]
									line = line + row[field].to_s + "\t"
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
								raise(SqlToFileError, "\nERROR: bad operator\n\n")
							end
						}
						writer.write(line + "\n")
						line = ""
					end
				# If the blocks in each row are considered a record
				else
					dbh.select_all(sql) do 
						| row |
						#Exclude chrN_random records
						unless (row[chromField] =~ /\w*_random/)
	
							#Check for alternate splicing
							name = row[nameField]
							if (nameHash.has_key?(name))
								spliceCount = nameHash.fetch(name)
								spliceCount = spliceCount + 1
								nameHash[name] = spliceCount
								name = name + "." + spliceCount.to_s
							else
								nameHash[name] = 0
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
								@inputField.each_index{									 
						      			|index|
						      			if(@operator[index] == 'constant')
						        			line = line + @inputField[index] + "\t"
					        			elsif(@operator[index] == '->')
						        			if (@inputField[index]  == blockStartField)
							        			line = line + blockStart.to_s + "\t"
						        			elsif(@inputField[index]  == blockEndField) && (seenBlockEnd == false)
							        			line = line + blockEnd.to_s + "\t"
											seenBlockEnd = true
						        			elsif(@inputField[index]  == nameField)
							        			line = line + name + "\t"
										elsif(@inputField[index] == targetStartField)
											line = line + targetStart.to_s + "\t"
										elsif(@inputField[index] == targetEndField)
											line = line + targetEnd.to_s + "\t"
						        			else
							        			field = @inputField[index]
							        			line = line + row[field].to_s + "\t"
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
						        			raise(SqlToFileError, "\nERROR: bad operator\n\n")
					        			end
					      			}
								writer.write(line + "\n")
								line = ""
								blockCount = blockCount + 1
							end
						end
					end
				end
				
				dbh.disconnect
			else 
				raise(SqlToFileError, "\nERROR: Output file not designated \n\n")
			end
		end #def mapObject

	end #class SqlToFile

#--------------------------------------------------------------------------------------------------------
#Class :  SqlToFileError
#Input :  Error message to be displayed to user.
#Output:  Outputs to StandardError.
#Usage :  raise(SqlToFileError, "Error Message")
#--------------------------------------------------------------------------------------------------------
	class SqlToFileError < StandardError ; end

end; end #module BRL; module SqlToFile
