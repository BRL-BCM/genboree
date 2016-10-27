#!/usr/bin/env ruby

require "zlib"

module BRL; module LDAS

	class LDASParseError < StandardError ; end

	class LDASAnnotation
		# Fields: class name type subtype ref start stop strand phase score tstart tend
	
		attr_accessor :classID, :tName, :type, :subtype, :refName, :rStart, :rEnd, :orientation, :phase, :score, :tStart, :tEnd, 
		attr_reader :numFields
		
		def initialize(input)
			#Number of fields in LDAS Annotation file
			@numFields = 12
		
			#Split input and place fields in attributes if correct number of fields
			input.chomp!
			arrSplit = input.split(/\s+/)
			if arrSplit.length == @numFields
				@classID, @tName, @type, @subtype, @refName, @rStart, @rEnd, @orientation, @phase, @score, @tStart, @tEnd = arrSplit
				
				#Convert to Zero Based Half Open
				@rStart = @rStart.to_i - 1
				if @orientation == "+"
					@tStart = @tStart.to_i - 1
				else
					@tEnd = @tEnd.to_i - 1
				end
				
			else
				raise (LDASParseError, "Incorrect LDAS Annontation format.")
			end
		end
		
		def getAsArray()
			#Returns LDAS Annotation fields as array
			getAsArray = @classID, @tName, @type, @subtype, @refName, @rStart, @rEnd, @orientation, @phase, @score, @tStart, @tEnd
		end
		
		def to_s(isZeroBased = true)
					
			if isZeroBased == false
				#Convert to 1 based	
				rStart = @rStart + 1

				if @orientation == "+"
					tStart = @tStart + 1
					tEnd = @tEnd
				else
					tEnd = @tEnd + 1
					tStart = @tStart
				end
			elsif isZeroBased == true
				rStart = @rStart
				tStart = @tStart
				tEnd = @tEnd
			else
				raise(TypeError,  "Incorrect isZeroBased parameter.")
			end
			
			to_s = @classID + "\t" +  @tName + "\t" + @type + "\t" +  @subtype + "\t" + @refName + "\t" +  rStart.to_s + "\t" +  @rEnd + "\t" +  @orientation + "\t" + @phase + "\t" + @score + "\t" + tStart.to_s + "\t" +  tEnd.to_s
		end
	end
	
	class LDASMultiAnnotation
			
		def initialize(file)
			if(FileTest.exist?(file) and FileTest.readable?(file))
				begin
					reader = BRL::Util::TextReader.new(file)
					reader.each {
						|line|
						test = line.split(/\s+/)
						if test.length == 12
							self.push(LDASAnnotation.new(line))
						end
					}
				rescue Exception => err
					raise err
				ensure
					reader.close() unless(reader.nil? or reader.closed?)
				end
			else
				raise(IOError, "LDAS file does not exist or is not readable")
			end
		end
		
		def outputLDASFile(fileOut, doGzip=true, refID, refClass, refLength, assemblyID, assemblyIDStart, assemblyIDEnd, assemblyClass, assemblyName, assemblyNameStart, assemblyNameEnd)
			writer = BRL::Util::TextWriter.new(fileOut, doGzip)
						
			#Prepend reference information
			writer.write("[references]\n#id\tclass\tlength\n")
			
			#Prepend assembly information
			writer.write("[assembly]\n#id\tstart\tend\tclass\tname\tstart\tend\n")
			
			self.each {
				|line|
				writer.write(line)
			}
			writer.close unless(writer.closed?)
		end
		
	end

end; end #module BRL; module LDAS
	
