#!/usr/bin/env ruby
$VERBOSE = (ENV['RUBY_VERBOSE'] == 'true' ? true : (ENV['RUBY_VERBOSE'] == 'false' ? false : nil))

=begin
This file implements the class FormatMapper within the *BRL::FormatMapper* module.

*FormatMapper* is initialized with a definition source that can be a file, string or standard IO.  The
definition source contains information to map attributes of one class to a second class.  Currently three
mappings are available that use three different operators.  The definition source has a required header and
can include comments on lines starting with #.  The following is an example:

#Comment line
Source Op Dest - This is the required header
sourceAttribute -> destinationAttribute
"Constant" constant destinationAttribute
sourceAttribute  regexp:"A regular expression" destinationAttribute

The -> operator is used for direct mapping of one attribute to another.  The constant operator allows the
placement of a constant in the destination attribute.  The regexp:"" operator uses a regular expression to
map one attribute to another.  The regular expression must be supplied by the user.

The method *mapObject* takes two required arguements and a third optional argument in order to map one object to
another.  The first arguement is an instantiated object of the source class.  The second argument is the name of
the destination class.  The optional third arguement is the name of an array class that can contain objects of
the destination class.

*FormatMapperError* is a private class used for error handling that inherits from the StandardError object.

Author: Alan Harris <rharris1@bcm.tmc.edu>
Date  : November 25, 2002
=end

require 'brl/util/textFileUtil'

module BRL; module FormatMapper

#--------------------------------------------------------------------------------------------------------
#Class :  FormatMapper
#Input :  definitionSrc = Information to map one object to a second object.
#Usage :  FormatMapper.new(definitionSrc)
#--------------------------------------------------------------------------------------------------------
	class FormatMapper
		attr_accessor :replaceSpacesInValues, :spaceReplaceStr

		def initialize(definitionSrc, replaceSpacesInValues=false)
			@replaceSpacesInValues = replaceSpacesInValues
			@spaceReplaceStr = '_'
			# First, check that we can read the mapping info from the source
			# Allows reading from Files, TextReaders, Arrays, Strings, Sockets, other IOs, etc
			unless(definitionSrc.respond_to?('each'))
				raise(FormatMapperError, "\nERROR: the argument to FormatMapper.new() must respond to the 'each' method!\n")
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
					raise(FormatMapperError,  "\nERROR: bad operation format line at #{lineNum}\n\n")
				end
				@inputField.push($1.strip)
				@operator.push($2.strip)
				@outputField.push($3.strip)
				lineNum+= 1
			}
		end #def initialize

		def mapObject(inputObject, outputClass, outputClassArray=nil)

			if(outputClassArray != nil)
			#If a class object and a class array of that object are passed as arguements
			#then instantiate the array and push individual class objects onto it.
				destArray = outputClassArray.new

				inputObject.each{
					|obj|
					dest = outputClass.new
					@inputField.each_index{
					|index|
					if(@operator[index] == 'constant')
						# check that the properties are present as required
						if not(dest.respond_to?(@outputField[index]))
							 raise(FormatMapperError, "\nERROR: Invalid destination object attribute '" + @outputField[index] + "' in definition file.\n")
						end
						# ok, now do the mapping
						evalStr = "dest.#{@outputField[index]} = #{@inputField[index]}"
						eval(evalStr)
						if(@replaceSpacesInValues
					elsif(@operator[index] == '->')
						if not (obj.respond_to?(@inputField[index]))
							raise(FormatMapperError, "\nERROR: Invalid source object attribute '" + @inputField[index] + "' in definition file.\n")
						elsif not (dest.respond_to?(@outputField[index]))
							 raise(FormatMapperError, "\nERROR: Invalid destination object attribute '" + @outputField[index] + "' in definition file.\n")
						end
						evalStr = "dest.#{@outputField[index]} = obj.#{@inputField[index]}"
						eval(evalStr)
					elsif(@operator[index] =~ /^regexp:/)
						if not (obj.respond_to?(@inputField[index]))
							 raise(FormatMapperError, "\nERROR: Invalid source object attribute '" + @inputField[index] + "' in definition file.\n")
						elsif not (dest.respond_to?(@outputField[index]))
							 raise(FormatMapperError, "\nERROR: Invalid desitination object attribute '" + @outputField[index] + "' in definition file.\n")
						end
						# trickier!!! because of multiple group possibilities with | separating.
						# We will be ~smart...the rule is that we take the first *matching* group
						# First, we need out regexp without the regexp: string in front and with quotes
						@operator[index] =~ /^regexp:\"(.+)\"$/
						reStr = $1
						evalStr = "dest.#{@outputField[index]} = Regexp.new('#{reStr}').match(obj.#{@inputField[index]}).to_a.compact[1]"
						eval(evalStr)
					else # unknown op line! raise appropriate error class
						raise(FormatMapperError, "\nERROR: bad operator\n\n")
					end
					}
					destArray.push(dest)
				}

				return destArray
			else #inputObject is single record object
				dest = outputClass.new

				@inputField.each_index{
					|index|
					if(@operator[index] == 'constant')
						# check that the properties are present as required
						if not(dest.respond_to?(@outputField[index].strip))
							 raise(FormatMapperError, "\nERROR: Invalid destination object attribute '" + @outputField[index] + "' in definition file.\n")
						end
						# ok, now do the mapping
						evalStr = "dest.#{@outputField[index]} = #{@inputField[index]}"
						eval(evalStr)
					elsif(@operator[index] == '->')
						if not (inputObject.respond_to?(@inputField[index].strip))
							raise(FormatMapperError, "\nERROR: Invalid source object attribute '" + @inputField[index] + "' in definition file.\n")
						elsif not (dest.respond_to?(@outputField[index].strip))
							 raise(FormatMapperError, "\nERROR: Invalid destination object attribute '" + @outputField[index] + "' in definition file.\n")
						end
						evalStr = "dest.#{@outputField[index]} = inputObject.#{@inputField[index]}"
						eval(evalStr)
					elsif(@operator[index] =~ /^regexp:/)
						if not (inputObject.respond_to?(@inputField[index].strip))
							 raise(FormatMapperError, "\nERROR: Invalid source object attribute '" + @inputField[index] + "' in definition file.\n")
						elsif not (dest.respond_to?(@outputField[index].strip))
							 raise(FormatMapperError, "\nERROR: Invalid desitination object attribute '" + @outputField[index] + "' in definition file.\n")
						end
						# trickier!!! because of multiple group possibilities with | separating.
						# We will be ~smart...the rule is that we take the first *matching* group
						# First, we need out regexp without the regexp: string in front and with quotes
						@operator[index] =~ /^regexp:\"(.+)\"$/
						reStr = $1
						evalStr = "dest.#{@outputField[index]} = Regexp.new('#{reStr}').match(inputObject.#{@inputField[index]}).to_a.compact[1]"
						eval(evalStr)
					else # unknown op line! raise appropriate error class
						raise(FormatMapperError, "\nERROR: bad operator\n\n")
					end
				}

				return dest
			end
		end #def mapObject

	end #class FormatMapper

#--------------------------------------------------------------------------------------------------------
#Class :  FormatMapperError
#Input :  Error message to be displayed to user.
#Output:  Outputs to StandardError.
#Usage :  raise(FormatMapperError, "Error Message")
#--------------------------------------------------------------------------------------------------------
	class FormatMapperError < StandardError ; end

end; end #module BRL; module FormatMapper
