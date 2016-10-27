#!/usr/bin/env ruby

=begin
=end
# ##############################################################################
# REQUIRED LIBRARIES
# #############################################################################
require 'brl/util/textFileUtil'
require 'brl/util/util'
require 'brl/util/propTable' # for PropTable class
require 'oci8' # for Oracle access (way faster than dbi)

module BRL ; module CAPSS

class ArrayLayoutRetriever
	PROP_KEYS =	%w{
								}
	POOL_ID, CLONE_NAME, PROJ, ARRAY_ID, ARRAY_ROW, ARRAY_COL =	0,1,2,3,4,5
	ORA_U, ORA_P, ORA_I = 'anyone', 'anyone', 'gsc'

	def initialize()

	end

	def run()
		@params = processArguments()
		retrieveDBRowsForArrays()
		recreateLayouts()
		dumpLayouts()
	end

	def retrieveDBRowsForArrays()
		@dbRowsForArrays = {}
		dbh = OCI8.new(ORA_U, ORA_P, ORA_I)
		prepCursor = dbh.parse('SELECT * FROM clone2project WHERE array = :1 ORDER BY project')
		@params['--arrayList'].each { |arrayID|
			arrayID.strip!
			@dbRowsForArrays[arrayID] = []
			numCols = prepCursor.exec(arrayID)
			while row = prepCursor.fetch()
				@dbRowsForArrays[arrayID] << row
			end
		}
		dbh.logoff
		return
	end

	def recreateLayouts()
		@arrayLayouts = {}
		@rowPools = {}
		@colPools = {}
		@dbRowsForArrays.each { |arrayID, rows|
			$stderr.puts '-'*50
			$stderr.puts "The DB rows for array #{arrayID}:"
			@arrayLayouts[arrayID] = []
			@rowPools[arrayID] = []
			@colPools[arrayID] = []
			pools2coords = {}
			# gather the coordinates for the pools
			rows.each { |row|
				$stderr.puts "\t#{row.join('  ')}"
				pool = row[PROJ].upcase
				pools2coords[pool] = [ [], [] ] unless(pools2coords.key?(pool))
				rowC,colC = row[ARRAY_ROW].to_i, row[ARRAY_COL].to_i
				rowC,colC = rowC-1, colC-1
				pools2coords[pool][0] << rowC
				pools2coords[pool][1] << colC

				@arrayLayouts[arrayID][rowC] = [] if(@arrayLayouts[arrayID][rowC].nil?)
				@arrayLayouts[arrayID][rowC][colC] = row[CLONE_NAME].strip
			}
			# collapse the coordinate lists to find out which pool is what
			pools2coords.each { |poolID, coords|
				rows = coords[0].uniq
				cols = coords[1].uniq
				if(rows.size == 1) # then this is a row pool
					@rowPools[arrayID][rows[0]] = poolID
				elsif(cols.size == 1) # then this is col pool
					@colPools[arrayID][cols[0]] = poolID
				else # oh oh, can't tell
					$stderr.puts "ERROR: Pool #{poolID} isn't clearly a row nor a column pool??\n\tRow coords: [ #{coords[0].join(', ')} ]\n\tCol coords: [ #{coords[1].join(', ')} ]"
				end
			}
		}
		return
	end

	def dumpLayouts()
		$stderr.puts '-'*50
		$stderr.puts "There are row pools for #{@rowPools.size} arrays (#{@rowPools.keys.sort.join(', ')})."
		$stderr.puts "There are col pools for #{@colPools.size} arrays (#{@colPools.keys.sort.join(', ')})."
		@rowPools.each { |arrayID, poolCoords|
			$stderr.puts "\tARRAY #{arrayID}: There are #{@rowPools[arrayID].size} row pools in this array."
			$stderr.puts "\tARRAY #{arrayID}: There are #{@colPools[arrayID].size} col pools in this array."
		}
		@rowPools.each { |arrayID, poolsCoords|
			$stderr.puts '-'*50
			$stderr.puts "Row pools for Array #{arrayID}:"
			poolsCoords.each_with_index { |poolID, ii|
				$stderr.puts "\t#{poolID}\t(#{ii})"
			}
		}
		@colPools.each { |arrayID, poolsCoords|
			$stderr.puts '-'*50
			$stderr.puts "Col pools for Array #{arrayID}:"
			poolsCoords.each_with_index { |poolID, ii|
				$stderr.puts "\t#{poolID}\t(#{ii})"
			}
		}
		@arrayLayouts.each { |arrayID, arrayLayout|
			Dir.recursiveSafeMkdir("#{@params['--outDir']}")
			writer = BRL::Util::TextWriter.new("#{@params['--outDir']}/array.#{arrayID}.layout.txt")
			# header row 1
			writer.print "       ARRAY\t   poolIndex\t"
			@colPools[arrayID].size.times { |ii| writer.print "#{(ii+1).to_s.rjust(12)}\t" }
			writer.puts ''
			# header row 2
			writer.print "   poolIndex\t       pools\t"
			@colPools[arrayID].size.times { |ii| writer.print "#{@colPools[arrayID][ii].rjust(12)}\t" }
			writer.puts ''
			# each row of table
			@rowPools[arrayID].size.times { |ii|
				# header col 1
				writer.print "#{(ii+1).to_s.rjust(12)}\t"
				# header col 2
				writer.print "#{@rowPools[arrayID][ii].rjust(12)}\t"
				@colPools[arrayID].size.times { |jj|
					if(arrayLayout[ii].nil?)
						cellContent = '-'*12 + "ii:#{ii}"
					else
						cellContent = arrayLayout[ii][jj]
						cellContent = (cellContent.nil?) ? '-'*12+"jj:#{jj}" : arrayLayout[ii][jj].rjust(12)
					end
					writer.print "#{cellContent}\t"
				}
				writer.puts ''
			}
			writer.close()
		}
		return
	end

	def processArguments()
		# We want to add all the prop_keys as potential command line options
		optsArray =	[
									['--outDir', '-o', GetoptLong::OPTIONAL_ARGUMENT],
									['--arrayList', '-a', GetoptLong::REQUIRED_ARGUMENT],
									['--verbose', '-v', GetoptLong::OPTIONAL_ARGUMENT],
									['--help', '-h', GetoptLong::NO_ARGUMENT]
								]
		PROP_KEYS.each {
			|propName|
			argPropName = "--#{propName}"
			optsArray << [argPropName, GetoptLong::OPTIONAL_ARGUMENT]
		}
		progOpts = GetoptLong.new(*optsArray)
		optsHash = progOpts.to_hash
		usage() if(optsHash.empty? or optsHash.key?('--help'))
		optsHash['--outDir'] = '.' unless(optsHash.key?('--outDir') and !optsHash['--outDir'].empty?)
		optsHash['--arrayList'] = optsHash['--arrayList'].split(',')
		@verbose = optsHash.key?('--verbose') ? true : false
		usage() unless(optsHash['--arrayList'].size > 0)
		return optsHash
	end

	def usage(msg='')
		unless(msg.empty?)
			puts "\n#{msg}\n"
		end
		puts "

PROGRAM DESCRIPTION:

  COMMAND LINE ARGUMENTS:
    -o     => [optional] Output dir where to place files (default is cwd)
    -a     => Comma separated list of array numbers to get from database
    -v     => [optional flag] Verbose output on stderr.
    -h     => [optional flag] Output this usage info and exit
  USAGE:
    arrayLayouts_fromDB.rb -o ./mapsAndIndices -a 23,24

";
		exit(134);
	end
end

end ; end

retriever = BRL::CAPSS::ArrayLayoutRetriever.new()
retriever.run()
exit(0)

