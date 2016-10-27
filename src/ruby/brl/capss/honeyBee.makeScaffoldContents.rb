#!/usr/bin/env ruby

=begin
  Author: Andrew R Jackson <andrewj@bcm.tmc.edu>
=end
# ##############################################################################
# REQUIRED LIBRARIES
# #############################################################################
require 'brl/util/textFileUtil'
require 'brl/util/util'
require 'brl/util/propTable' # for PropTable class
require 'brl/similarity/blatHit'

# Turn on extra warnings and such
$VERBOSE = true

#=== *Purpose* :
#  Namespace for BRL's directly-related Genboree Ruby code.
module BRL ; module CAPSS
	class Scaffold
		attr_accessor :name, :length
		attr_accessor :contigs

		def initialize(name=nil, length=nil)
			@name = name
			@length = length
			@contigs = {}
		end
		alias :size :length
	end # class Scaffold

	class Contig
		attr_accessor :name, :scaffoldStart, :length, :orientation
		attr_accessor :reads
		attr_accessor :reads2contigs

		def initialize(name=nil, scaffoldStart=nil, length=nil, orient=nil)
			@name, @scaffoldStart, @length, @orientation = name, scaffoldStart, length, orient
			@reads = {}
		end

		alias :size :length
	end # class Contig

	class Read
		attr_accessor :name, :contigStart, :length, :orientation

		def initialize(name=nil, contigStart=nil, length=nil, orient=nil)
			@name, @contigStart, @length, @orientation = name, contigStart, length, orient
		end
	end # class Read

	class ScaffoldContents
		attr_accessor :reads2contigPslFileName, :contigs2scaffoldFileName
		attr_accessor :scaffolds
		attr_accessor :tooSmallContigs
		attr_accessor :contigs2scaffolds, :reads2contigs

		# Required properties


		# * *Function*:
		# * *Usage*   : <tt>    </tt>
		# * *Args*    :
		#   - ++  ->
		# * *Returns* :
		#   - ++  ->
		# * *Throws* :
		#   - +none+
		# --------------------------------------------------------------------------
		def initialize(optsHash)
			setParameters(optsHash)
			@scaffolds = {}
			@contigs2scaffolds = {}
			@reads2contigs = {}
			@tooSmallContigs = {}
		end

		# * *Function*:
		# * *Usage*   : <tt>    </tt>
		# * *Args*    :
		#   - ++  ->
		# * *Returns* :
		#   - ++  ->
		# * *Throws* :
		#   - +none+
		# --------------------------------------------------------------------------
		def setParameters(optsHash)
			@reads2contigsPslFileName = optsHash['--reads2contigsFile']
			@contigs2scaffoldFileName = optsHash['--contigs2scaffoldsFile']
			@readType = optsHash.key?('--readTypeStr') ? optsHash['--readTypeStr'] : 'READ'
			return
		end

		# * *Function*:
		# * *Usage*   : <tt>    </tt>
		# * *Args*    :
		#   - ++  ->
		# * *Returns* :
		#   - ++  ->
		# * *Throws* :
		#   - +none+
		# --------------------------------------------------------------------------
		def loadContigs2ScaffoldsFile()
			$stderr.puts "STATUS: opening '#{@contigs2scaffoldFileName}' to read in scaffold contents."
			reader = BRL::Util::TextReader.new(@contigs2scaffoldFileName)
			# Search through for the scaffold section
			foundScaffoldSection = false
			firstScaffoldLine = ''
			while((firstScaffold = reader.readline()) !~ /^SCAFFOLD/)
				next
			end
			# Found scaffold section
			# Suck in rest of content
			scaffoldSection = reader.read()
			# Split into scaffolds
			scaffoldRecords = scaffoldSection.split(/SCAFFOLD:\s*/)
			# Remove first record [blank]
			scaffoldRecords.shift
			# Process the records
			scaffoldRecords.each {
				|rec|
				lines = rec.split("\n")
				scaffFields = lines.shift.strip.split(/\s+/)
				scaffID = scaffFields[0]
				scaffLength = scaffFields[1].to_i
				scaffold = BRL::CAPSS::Scaffold.new(scaffID, scaffLength)
				lines.each {
					|contigLine|
					contigLine =~ /^(Contig\d+)\:\s+(\-?\d+)\s+(\-?\d+)\s+(\+|\-)/
					contigID, scaffStart, scaffEnd, orient = $1, $2.to_i, $3.to_i, $4
					if(scaffStart > scaffEnd) then scaffStart,scaffEnd = scaffEnd,scaffStart ; end
					scaffLen = (scaffStart >0) ? (scaffEnd-scaffStart)+1 : (scaffEnd-scaffStart)
					contig = BRL::CAPSS::Contig.new(contigID, scaffStart, scaffLen, orient)
					scaffold.contigs[contig.name] = contig
					@contigs2scaffolds[contig.name] = scaffold
				}
				@scaffolds[scaffold.name] = scaffold
			}
			return
		end

		# * *Function*:
		# * *Usage*   : <tt>    </tt>
		# * *Args*    :
		#   - ++  ->
		# * *Returns* :
		#   - ++  ->
		# * *Throws* :
		#   - +none+
		# --------------------------------------------------------------------------
		def loadReads2ContigsFile()
			$stderr.puts "STATUS: opening '#{@reads2contigsPslFileName}' to read in contigs."
			reader = BRL::Util::TextReader.new(@reads2contigsPslFileName)
			bhArray = BRL::Similarity::BlatMultiHit.new(reader)
			reader.close unless(reader.nil? or reader.closed?)
			bhArray.each {
				|blatHit|
				read = BRL::CAPSS::Read.new(blatHit.qName, blatHit.tStart, blatHit.qSize, blatHit.orientation)
				begin
					@contigs2scaffolds[blatHit.tName].contigs[blatHit.tName].reads[read.name] = read
					@reads2contigs[read.name] = @contigs2scaffolds[blatHit.tName].contigs[blatHit.tName]
				rescue
					unless(@tooSmallContigs.key?(blatHit.tName))
						@tooSmallContigs[blatHit.tName] = BRL::CAPSS::Contig.new(blatHit.tName, 1, blatHit.tSize, '+')
					end
					@tooSmallContigs[blatHit.tName].reads[read.name] = read
					@reads2contigs[read.name] = @tooSmallContigs[blatHit.tName]
				end
			}
			return
		end

		# * *Function*:
		# * *Usage*   : <tt>    </tt>
		# * *Args*    :
		#   - ++  ->
		# * *Returns* :
		#   - ++  ->
		# * *Throws* :
		#   - +none+
		# --------------------------------------------------------------------------
		def dumpScaffoldContents()
			@scaffolds.each {
				|scaffID, scaffRec|
				puts "SCAFFOLD\t#{scaffRec.name}\t#{scaffRec.length}"
				scaffRec.contigs.values.sort{|aa,bb| aa.scaffoldStart <=> bb.scaffoldStart}.each {
					|contigRec|
					puts "\tCONTIG\t#{contigRec.name}\t#{contigRec.scaffoldStart}\t#{contigRec.length}\t#{contigRec.orientation}"
					contigRec.reads.values.sort{|aa,bb| aa.contigStart <=> bb.contigStart}.each {
						|readRec|
						puts "\t\t#{@readType}\t#{readRec.name}\t#{readRec.contigStart}\t#{readRec.length}\t#{readRec.orientation}"
					}
				}
			}
			@tooSmallContigs.each {
				|contigID, contigRec|
				$stderr.puts "TOO_SMALL_CONTIG\t#{contigRec.name}\t#{contigRec.scaffoldStart}\t#{contigRec.length}\t#{contigRec.orientation}"
				contigRec.reads.values.sort{|aa,bb| aa.contigStart <=> bb.contigStart}.each {
					|readRec|
					$stderr.puts "\t#{@readType}\t#{readRec.name}\t#{readRec.contigStart}\t#{readRec.length}\t#{readRec.orientation}"
				}
			}
			return
		end

		# * *Function*:
		# * *Usage*   : <tt>   </tt>
		# * *Args*  :
		#   - +none+
		# * *Return* :
		#   - +Hash+  ->
		# * *Throws* :
		#   - +none+
		# --------------------------------------------------------------------------
		def ScaffoldContents.processArguments
			# We want to add all the prop_keys as potential command line options
			optsArray =	[
										['--reads2contigsFile', '-r', GetoptLong::REQUIRED_ARGUMENT],
										['--contigs2scaffoldsFile', '-c', GetoptLong::REQUIRED_ARGUMENT],
										['--readTypeStr', '-a', GetoptLong::OPTIONAL_ARGUMENT],
										['--help', '-h', GetoptLong::NO_ARGUMENT]
									]
			progOpts = GetoptLong.new(*optsArray)
			optsHash = progOpts.to_hash
			ScaffoldContents.usage() if(optsHash.empty? or optsHash.key?('--help'));
			return optsHash
		end

	  # * *Function*: Displays some basic usage info on STDOUT
	  # * *Usage*   : <tt>  </tt>
	  # * *Args*  :
	  #   - +String+ Optional message string to output before the usage info.
	  # * *Return* :
	  #   - +none+
	  # * *Throws*  :
	  #   - +none+
		# --------------------------------------------------------------------------
		def ScaffoldContents.usage(msg='')
			unless(msg.empty?)
				puts "\n#{msg}\n"
			end
			puts "

  PROGRAM DESCRIPTION:


    COMMAND LINE ARGUMENTS:
      -r    => File containing reads mapped to contigs, in psl format
      -c    => File containing contigs mapped to scaffolds, in Bingshan's '.scaffold' format
      -a    => String to use for the 'reads' mapped to the contig. Default is 'READ'.
      -h    => [optional flag] Output this usage info and exit

    USAGE:
	";
			exit(2);
		end # def LFFMerger.usage(msg='')
	end # class ScaffoldContents
end ; end

# ##############################################################################
# MAIN
# ##############################################################################
# process command line options
optsHash = BRL::CAPSS::ScaffoldContents.processArguments()
assembly = BRL::CAPSS::ScaffoldContents.new(optsHash)
# load scaffold file
assembly.loadContigs2ScaffoldsFile()
# load reads file
assembly.loadReads2ContigsFile()
# save scaffold contents
assembly.dumpScaffoldContents()

exit(0)
