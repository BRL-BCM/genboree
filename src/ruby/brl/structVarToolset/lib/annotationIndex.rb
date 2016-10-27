#!/usr/bin/env ruby
require 'set'

module BRL
module Pash

# Elements of this class will be used to populate the annotation index
class IndexableAnnotation
	attr_reader :chrom
	attr_reader :chromStart
	attr_reader :chromStop

	# user-defined additional info
	attr_reader  :info
	
	def initialize(_chrom, _start, _stop, _info)
		@chrom = _chrom
		@chromStart = _start
		@chromStop = _stop
		@info = _info
	end
end

class AnnotationIndex
	DEBUG=false
	attr_reader :annotationHash
	
	def initialize()
		@annotationHash = {}
		@window = 100000
	end
	
	# Add a new annotation to annotation index
	def addAnnotation(chromosome, start, stop, info)
		s = IndexableAnnotation.new(chromosome, start, stop, info);
		$stderr.puts "Attempt to index #{chromosome} #{start} #{stop} e.g. #{s.chrom} #{s.chromStart} #{s.chromStop} " if (DEBUG)
		if (!@annotationHash.key?(chromosome)) then
			@annotationHash[chromosome] = {}
		end
		chromosomeHash = @annotationHash[chromosome]
		chromSlice1 = start/@window
		chromSlice2 = stop/@window
		slice = nil
		chromSlice1.upto(chromSlice2) {|slice|
			if (chromosomeHash.key?(slice)) then
				chromosomeHash[slice].push(s)
			else
				chromosomeHash[slice] = [s]
			end
			$stderr.puts "#{s.chrom} #{s.chromStart} #{s.chromStop} on #{chromosome} at #{slice}" if (DEBUG)
		}
	end

	# Returns a set containing all annotations that overlap w/ query
	def getOverlappingAnnotations(chromosome, start, stop)
		if (!@annotationHash.key?(chromosome))
			$stderr.puts "chromo #{chromosome} not found" if (DEBUG)
			return nil
		end
		chromosomeHash = @annotationHash[chromosome]
		$stderr.puts "looking for #{start}-#{stop} in a hash w/ #{chromosomeHash.size} elements\n" if (DEBUG)
    myWindows = Set.new()
		chromSlice1 = start.to_i/@window
		chromSlice2 = stop.to_i/@window
		chromSlice1.upto(chromSlice2) {|slice|
			if (chromosomeHash.key?(slice)) then
				coverageArray = chromosomeHash[slice]
				$stderr.puts "looking up in coverage array #{coverageArray} at slice #{slice}" if (DEBUG)
				coverageArray.each { |s|
					$stderr.puts "current annotation #{s.chrom}: #{s.chromStart}-#{s.chromStop}" if (DEBUG)
					if ((s.chromStart <= stop)  && (s.chromStop >= start))
						if (!myWindows.member?(s)) then
              myWindows.add(s)
              $stderr.puts "adding covered annotation #{s}" if (DEBUG)  
						end
					end
				}			
			end
		}
		if (myWindows.size>0) then
			return myWindows.to_a
		else
			return nil
		end
	end

	def dumpAnnotationIndex ()
		@annotationHash.keys.each {|k|
			chromosomeHash = @annotationHash[k]
			$stderr.puts "Dumping #{chromosomeHash.size} annotations on chromosome #{k}	" if (DEBUG)
			chromosomeHash.keys.each {|slice|
				$stderr.puts "slice #{slice}: #{chromosomeHash[slice].join("\t")}" if (DEBUG)
			}
		}
	end

end

end
end
