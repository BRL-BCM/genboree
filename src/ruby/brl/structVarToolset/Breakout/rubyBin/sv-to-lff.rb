#!/usr/bin/env ruby
require 'getoptlong'

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

class SV2Lff
  DEBUG =false 
  def initialize(optsHash)
		@optsHash = optsHash
		setParameters()
	end

  def setParameters()
		@breakpointFile = @optsHash['--breakpointFile']
		if (@optsHash['--orientation']=~ /same/i) then
      @sameStrandPairs = true
		else
      @sameStrandPairs = false
		end
		$stderr.puts "same strand pairs #{@sameStrandPairs}" 
		@svLffFile = 			@optsHash['--svLffFile']
		@newClass = "StructVariants"
		@newSubtype = "Breakpoints"
		if (@optsHash.key?('--newClass')) then
			@newClass = @optsHash['--newClass']
		end
		if (@optsHash.key?('--newSubtype')) then
			@newSubtype = @optsHash['--newSubtype']
		end
		@minInsert = @optsHash['--minInsert'].to_i
		@maxInsert = @optsHash['--maxInsert'].to_i
		
		@experimentName = @optsHash['--experimentName'].strip.gsub(/\s/, "_")
    if (@experimentName == "") then
			$stderr.puts "Invalid experiment name #{@experimentName}"
			exit(2)
    end
		@newType=@experimentName
		@svXLSFile=@optsHash['--svXLSFile']
		@minCoverage=@optsHash['--minCoverage'].to_i
		if (@minCoverage<2) then
      $stderr.puts "minimum coverage should not be lower than 2"
      exit(2)
		end
		
		$stderr.puts "Convert input file to #{@svLffFile} class #{@newClass} type #{@newType} subtype #{@newSubtype}" if (DEBUG)
  end

	def callBreakpointEvent(chrom1, chrom1Start, chrom1Stop, chrom2, chrom2Start, chrom2Stop, l)
		l =~/MPC:\s+(\S+)\s+\S+\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)/

		matesNumber = $1.to_i
		rawInsertSize  = (chrom2Start+chrom2Stop)/2 - (chrom1Start+chrom1Stop)/2
		insertSize = 0
		if (rawInsertSize<@minInsert) then
			insertSize = rawInsertSize-@minInsert
		elsif (rawInsertSize>@maxInsert) then
			insertSize = rawInsertSize -@maxInsert
		else
			insertSize = 0
		end

    i1 = l.scan(/\s\+\s+\d+\s+\d+\s+\+\s/)
    i2 = l.scan(/\s\-\s+\d+\s+\d+\s+\-\s/)
    i3 = l.scan(/\s\+\s+\d+\s+\d+\s+\-\s/)
    i4 = l.scan(/\s\-\s+\d+\s+\d+\s+\+\s/)
    ssame = i1.size+i2.size
    sopp = i3.size + i4.size
    $stderr.puts "ssame #{ssame} opp #{sopp}" if (DEBUG)
    # determine dominant strands
    maxStrandArray = i1
    strand1 = "+"
    strand2="+"
    if (maxStrandArray.size<i2.size) then
      maxStrandArray = i2
      strand1 = "-"
      strand2 = "-"
    end
    if (maxStrandArray.size<i3.size) then
      maxStrandArray = i3
      strand1 = "+"
      strand2 = "-"
    end
    if (maxStrandArray.size<i4.size) then
      maxStrandArray = i4
      strand1 = "-"
      strand2 = "+"
    end
    
    if (chrom1!=chrom2) then
      return ["Translocation", strand1, strand2]
    end
    
    if ( (@sameStrandPairs && sopp>ssame) ||
       (!@sameStrandPairs && ssame>sopp)) then
      return ["Inversion", strand1, strand2]
    end
		

		if (insertSize.to_f<0) then
			# most likely insertion
			return ["Insertion", strand1, strand2]
		elsif (insertSize.to_f>10000000) then
			# label the event as a translocation
			return ["Translocation", strand1, strand2]
		else
			if (insertSize>0) then
				return ["Deletion", strand1, strand2]
			else
				return ["Unclear", strand1, strand2]
			end
		end
	end

	def convertBreakpoints()
		clusterReader = File.open(@breakpointFile,"r")
		xlsWriter = File.open(@svXLSFile, "w")
		xlsWriter.puts "SV Name\tChrom 1\tChrom 1 start\tChrom 1 stop\tChrom1 Strand\tChrom 2\tChrom 2 start\tChrom 2 stop\tChrom2 strand\tCoverage\tType"

		outputWriter = File.open(@svLffFile,"w")
		l = nil
		svIdx = 0
		clusterReader.each {|l|
			f = l.split(/\t/)
			l =~/MPC:\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)/
			coverage  = $1.to_i
			next if (coverage<@minCoverage)
			chrom1 = $3
			chrom1Start = $4.to_i
			chrom1Stop = $5.to_i
			chrom2 = $6
			chrom2Start = $7.to_i
			chrom2Stop = $8.to_i
                        $stderr.puts "work with #{chrom1} #{chrom2} #{chrom1Start} #{chrom1Stop} #{chrom2} #{chrom2Start} #{chrom2Stop}" if (DEBUG)
                        next if (chrom1==chrom2 && chrom1Start<=chrom2Stop && chrom2Start<=chrom1Stop)
			
			$stderr.puts "chroms #{chrom1} #{chrom2}" if (DEBUG)
			svAttributes = callBreakpointEvent(chrom1, chrom1Start, chrom1Stop, chrom2, chrom2Start, chrom2Stop, l)
			svType = svAttributes[0]
			strand1 = svAttributes[1]
			strand2 = svAttributes[2]
			$stderr.puts "svAttributes=#{svAttributes}" if (DEBUG)
			if (svType=="Unclear") then
				$stderr.puts "unclear: #{l.strip}"
				next
			end
			avp1 = []
			avp1.push("mateType=#{svType}")
			avp1.push("mateChrom=#{chrom2}")
			avp1.push("mateStart=#{chrom2Start}")
			avp1.push("mateStop=#{chrom2Stop}")
			avp1.push("matePairsCount=#{coverage}")
			avp1.push("minInsert=#{@minInsert}")
			avp1.push("maxInsert=#{@maxInsert}")
			avp2 = []
			avp2.push("mateType=#{svType}")
			avp2.push("mateChrom=#{chrom1}")
			avp2.push("mateStart=#{chrom1Start}")
			avp2.push("mateStop=#{chrom1Stop}")
			avp2.push("matePairsCount=#{coverage}")
			avp2.push("minInsert=#{@minInsert}")
			avp2.push("maxInsert=#{@maxInsert}")
			outputWriter.puts "#{@newClass}\t#{@experimentName}.SV.#{svIdx}\t#{@newType}\t#{@newSubtype}\t#{chrom1}\t#{chrom1Start}\t#{chrom1Stop}\t#{strand1}\t0\t#{coverage}\t.\t.\t#{avp1.join("; ")};"
			outputWriter.puts "#{@newClass}\t#{@experimentName}.SV.#{svIdx}\t#{@newType}\t#{@newSubtype}\t#{chrom2}\t#{chrom2Start}\t#{chrom2Stop}\t#{strand2}\t0\t#{coverage}\t.\t.\t#{avp2.join("; ")};"
			xlsWriter.puts "#{@experimentName}.SV.#{svIdx}\t#{chrom1}\t#{chrom1Start}\t#{chrom1Stop}\t#{strand1}\t#{chrom2}\t#{chrom2Start}\t#{chrom2Stop}\t#{strand2}\t#{svType}"
			svIdx += 1
		}
		outputWriter.close()
		clusterReader.close()
		xlsWriter.close()
	end

  def work()
		convertBreakpoints()
		
  end

  def SV2Lff.processArguments()
		# We want to add all the prop_keys as potential command line options
		optsArray =	[ ['--orientation',   	'-O', GetoptLong::OPTIONAL_ARGUMENT],
								  ['--breakpointFile',	'-b', GetoptLong::OPTIONAL_ARGUMENT],
									['--svLffFile',    		'-l', GetoptLong::REQUIRED_ARGUMENT],
									['--newClass',				'-C', GetoptLong::OPTIONAL_ARGUMENT],
									['--newType',					'-T', GetoptLong::OPTIONAL_ARGUMENT],
									['--newSubtype',			'-S', GetoptLong::OPTIONAL_ARGUMENT],
									['--minInsert',			  '-m', GetoptLong::REQUIRED_ARGUMENT],
									['--maxInsert',		  	'-M', GetoptLong::REQUIRED_ARGUMENT],
									['--experimentName',	'-E', GetoptLong::REQUIRED_ARGUMENT],
									['--minCoverage',	    '-x', GetoptLong::REQUIRED_ARGUMENT],
									['--svXLSFile',     	'-X', GetoptLong::REQUIRED_ARGUMENT],
									['--help',            '-h', GetoptLong::NO_ARGUMENT]
			]

		progOpts = GetoptLong.new(*optsArray)
		optsHash = {}
		
		progOpts.each do |opt, arg|
      case opt
        when '--help'
          SV2Lff.usage("")
        when '--orientation'
          optsHash['--orientation'] = arg
        when '--breakpointFile'
          optsHash['--breakpointFile']=arg
        when '--svLffFile'
          optsHash['--svLffFile']=arg
        when '--newClass'
          optsHash['--newClass']=arg
        when '--newType'
          optsHash['--newType']=arg
        when '--newSubtype'
          optsHash['--newSubtype']=arg
        when '--minInsert'
          optsHash['--minInsert']=arg
        when '--maxInsert'
          optsHash['--maxInsert']=arg
        when '--experimentName'
          optsHash['--experimentName']=arg
        when '--svXLSFile'
          optsHash['--svXLSFile']=arg
        when '--minCoverage'
          optsHash['--minCoverage']=arg
      end
    end

		SV2Lff.usage() if(optsHash.empty?);
		if (!optsHash.key?("--svLffFile") || !optsHash.key?("--minInsert") || !optsHash.key?("--maxInsert") ||
				 !optsHash.key?("--experimentName") || !optsHash.key?("--svXLSFile") || !optsHash.key?('--minCoverage')) then
			SV2Lff.usage("USAGE ERROR: some required arguments are missing")
		end
		return optsHash
	end

	def SV2Lff.usage(msg='')
    unless(msg.empty?)
      puts "\n#{msg}\n"
    end
    puts "
PROGRAM DESCRIPTION:
  This utility takes in SV calls in the form of individual
breakpoints clusters and generates lff and TAB-delimited files containing the SV calls.


COMMAND LINE ARGUMENTS:
  --breakpointFile       | -b   => raw breakpoint file generated by Breakout
  --orientation          | -O   => consistent matepair orientation: same/opposite
  --svLffFile            | -l   => LFF file containing the sv calls
  --newClass             | -C   => [optional] class of the lff output file, default StructVariants
  --newType              | -T   => [optional] type of the lff output file, default SV
  --newSubtype           | -S   => [optional] subtype of the lff output file, default Calls
  --minInsert            | -m   => minimum insert size
  --maxInsert            | -M   => maximum insert size
  --experimentName       | -E   => experiment name
  --svXLSFile            | -X   => output spreadsheet
  --minCoverage          | -x   => minimum coverage
  --help                 | -h   => [optional] output this usage info and exit

USAGE:
  sv-to-lff.rb  -c svcalss -l svacall.lff
";
		exit(2);
	end
end

########################################################################################
# MAIN
########################################################################################

# Process command line options
optsHash = SV2Lff.processArguments()
# Instantiate analyzer using the program arguments
boilerPlate = SV2Lff.new(optsHash)
# Analyze this !
boilerPlate.work()
exit(0);
