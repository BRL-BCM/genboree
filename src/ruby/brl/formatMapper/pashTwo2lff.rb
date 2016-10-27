#!/usr/bin/env ruby
# ##############################################################################
# $Copyright:$
# ##############################################################################

# Author: Andrew R Jackson (andrewj@bcm.tmc.edu)
# Date: 3/31/2004 4:38PM
# Cristian Coarfa (coarfa@bcm.tmc.edu)
# Date 2/4/2008
# Purpose:
# Converts the Pash output format to LFF, which is used by Genboree, the
# lffMerger, and other tools.

# ##############################################################################
# REQUIRED LIBRARIES
# ##############################################################################
require 'brl/util/textFileUtil'
require 'brl/util/util'

module BRL ; module PASH
	CCDEBG = false
	MAX_NUM_ERRORS = 25
	MAX_EMAIL_ERRS = 25
  MAX_EMAIL_SIZE = 30_000

	class PashHit
		@@matchGain = 1
		@@mismatchPenalty = -3
		@@gapInitPenalty = -5
		@@gapExtendPenalty = -2
		attr_reader :message

		def initialize()
			message=nil
			@target = nil
			@targetStart = nil
			@targetStop = nil
			@query = nil
			@queryStart = nil
			@queryStop = nil
			@strand = nil
			@numMatches = nil
			@numMismatches = nil
			@numGaps = nil
			@numGapBases = nil
			@numBlocks = nil
			@blockSizes = nil
			@targetBlockStarts = nil
			@queryBlockStarts = nil
		end


		def set(line)
			ff = line.split(/\t/)
			@message = ""
			result = 0
			target_name, target_start, target_stop, query_name, query_start, query_stop, strand_pos=0,1,2,3,4,5,6
			matches, mismatches, gaps, gap_bases, num_blocks, block_sizes, target_block_starts, query_block_starts=7,8,9,10,11,12,13,14
			integerFields = [1,2,4,5,7,8,9,10,11]
			if (ff.size>=15) then
				@numMismatches = ff[8].to_i
			elsif(ff.size==14) then
				matches, mismatches, gaps, gap_bases, num_blocks, block_sizes, target_block_starts, query_block_starts=7,-1,8,9,10,11,12,13
				integerFields = [1,2,4,5,7,8,9,10]
				@numMismatches = 0
			#else
			#	result =  1
			#	@message = "- More fields: #{ff.size} than expected."
			end

			if (result == 0) then
				integerFields.each {|k|
					if (ff[k] !~ /^\+*(\d+)$/) then
						@message << "- Expecting an integer for field #{k+1}, got #{ff[k]}\n"
						result = 1
					end
				}
				if (ff[strand_pos] !~ /^\+|\-$/) then
					@message << "- Field #{strand_pos+1} should contain a + or - strand, got #{ff[strand_pos+1]}"
					result = 1
				end

				@target = ff[target_name]
				@targetStart = ff[target_start].to_i
				@targetStop = ff[target_stop].to_i
				@query = ff[query_name]
				@queryStart = ff[query_start].to_i
				@queryStop = ff[query_stop].to_i
				@strand = ff[strand_pos]
				@numMatches = ff[matches].to_i

				@numGaps = ff[gaps].to_i
				@numGapBases = ff[gap_bases].to_i
				@numBlocks = ff[num_blocks].to_i
				@blockSizes = ff[block_sizes].split(/,/)
				@blockSizes.each {|k|
					if (k !~ /^\+*(\d+)$/) then
						@message << "- Expecting a comma-separated list of integer for field #{12+1} , got #{ff[12]}\n"
						result = 1
						break
					end
				}
				@targetBlockStarts = ff[target_block_starts].split(/,/)
				@targetBlockStarts.each {|k|
					if (k !~ /^\+*(\d+)$/) then
						@message << "- Expecting a comma-separated list of integer for field #{13+1} , got #{ff[13]}\n"
						result = 1
						break
					end
				}

				@queryBlockStarts = ff[query_block_starts].split(/,/)
				@queryBlockStarts.each {|k|
					if (k !~ /^\+*(\d+)$/) then
						@message << "- Expecting a comma-separated list of integer for field #{14+1} , got #{ff[14]}\n"
						result = 1
						break
					end
				}
		  end

			$stderr.puts "result #{result}" if (CCDEBG)
			if (result==0) then
				$stderr.puts "target #{@target} tStart #{@targetStart} tStop #{@targetStop} "+
					 "query #{@query} qStart #{@queryStart} qStop #{@queryStop} strand #{@strand} "+
					 "M #{@numMatches} m #{@numMismatches} gaps #{@numGaps} gap bases #{@numGapBases} " if (CCDEBG)
				$stderr.puts "blocks #{@numBlocks} blockSizes #{@blockSizes.join(';')} "+
					 "tBStarts #{@targetBlockStarts.join(';')} qBStarts #{@queryBlockStarts}" if (CCDEBG)
			end
			return result
		end

		def toLff(lffClass, lffType, lffSubtype, queryCount, queryFirst=false)
			result = ""
			$stderr.puts "#{@numMatches} #{@@matchGain}" if (CCDEBG)
			score  = @numMatches*@@matchGain
			score += @numMismatches*@@mismatchPenalty
			score += @numGaps*@@gapInitPenalty
			score += @numGapBases*@@gapExtendPenalty
			$stderr.puts "score #{score}" if (CCDEBG)
			$stderr.puts "queryFirst #{queryFirst}" if (CCDEBG)
			avp = "matchingBases=#{@numMatches}; mismatches=#{@numMismatches}; gaps=#{@numGaps}; gapBases=#{@numGapBases}"
			if (!queryFirst) then
				@numBlocks.times { |i|
					result <<"#{lffClass}\t#{@query}.#{queryCount}\t#{lffType}\t#{lffSubtype}\t#{@target}\t#{@targetBlockStarts[i]}\t#{@targetBlockStarts[i].to_i+@blockSizes[i].to_i-1}\t"+
						"#{@strand}\t.\t#{score}\t#{@queryBlockStarts[i]}\t#{@queryBlockStarts[i].to_i+@blockSizes[i].to_i-1}\t#{avp}\n"
				}
			else
				@numBlocks.times { |i|
					result <<"#{lffClass}\t#{@target}.#{queryCount}\t#{lffType}\t#{lffSubtype}\t#{@query}\t#{@queryBlockStarts[i]}\t#{@queryBlockStarts[i].to_i+@blockSizes[i].to_i-1}\t"+
						"#{@strand}\t.\t#{score}\t#{@targetBlockStarts[i]}\t#{@targetBlockStarts[i].to_i+@blockSizes[i].to_i-1}\t#{avp}\n"
				}
			end
			return result
		end

	end


	class Pash2Lff
		MAX_NUM_ERRORS = 25

		# ACCESSORS
		attr_accessor :className, :type
		attr_accessor :targetID, :nameForward
		attr_accessor :queryID, :nameReverse
		attr_accessor :errMsgs

		DEFAULT_CLASS = "Pash"
		DEFAULT_TYPE = "Pash"
		DEFAULT_SUBTYPE = "Hit"

		# METHODS

    # * *Function*: Creates a new PashToLff instance.
		# * *Usage*   : <tt>  converter = BRL::PASH::PashToLff.new(optionsHash)  </tt>
		# * *Args*    :
		#   - +optionsHash+  ->  A hash of the command line options obtained from
		#     BRL's GetoptLong#to_hash function. Minmally requires
		#     '-p' and '-f' keys for properties file name and pash
		#     file name be in there.
		# * *Returns* :
		#   - +PashToLff+  -> New object instance .
		# * *Throws* :
		#   - +none+
		# --------------------------------------------------------------------------
		def initialize(optsHash)
		  @optsHash = optsHash
			setParameters()
		end

    # * *Function*: Processes program parameters and sets up internal representations of
    #   the parameters.
    # * *Usage*   : <tt>  pashToLffObj.setParameters()  </tt>
    # * *Args*    :
    #   - +none+
    # * *Returns* :
    #   - +none+
    # * *Throws*  :
    #   - +none+
		# --------------------------------------------------------------------------
		def setParameters()
		  @pashFile = @optsHash['--inputFile']

		  if (@optsHash.key?('--class')) then
				@className = @optsHash['--class']
		  else
				@className = DEFAULT_CLASS
		  end

		  if (@optsHash.key?('--type')) then
				@type = @optsHash['--type']
		  else
				@type = DEFAULT_TYPE
		  end

		  if (@optsHash.key?('--subtype')) then
				@subtype = @optsHash['--subtype']
		  else
				@subtype = DEFAULT_SUBTYPE
		  end


			if (@optsHash.key?('--doGzipOutput')) then
				@doGzipOutput = true
			else
				@doGzipOutput = false
			end

			if (@optsHash.key?('--outputFile')) then
				@outputFile = @optsHash['--outputFile']
			else
				if (@doGzipOutput) then
					@outputFile = "#{@pashFile}.lff.gz"
				else
					@outputFile = "#{@pashFile}.lff"
				end
			end

			@recsPerBlock = 0
			if (@optsHash.key?('--recBlockSize')) then
				@recsPerBlock = @optsHash['--recBlockSize'].to_i
			end
			if (@optsHash.key?('--queryFirst')) then
				@queryFirst = true
			else
				@queryFirst = false
			end

			$stderr.puts "pashFile #{@pashFile} output file #{@outputFile} class #{@className}"+
			  "type #{@type} subtype #{@subtype} gzipOut? #{@doGzipOutput} block size "+
			  "#{@recBlockSize} queryFirst #{@queryFirst}" if (CCDEBG)
			return
		end

    # * *Function*: Converts the pash file to 2 lff files, one using each genome as
    #   the reference sequence.
    # * *Usage*   : <tt>  pashToLffObj.convertPashFile()  </tt>
    # * *Args*    :
    #   - +pashFileName+ Optional pash file name. Otherwise uses -f switch value.
    #     Default is nil.
    # * *Returns* :
    #   - +StandardError+ -> If the pash file doesn't exist or is not formatted correctly.
		# --------------------------------------------------------------------------
		def convertPashFiles(pashFile=@pashFile)
		  if(pashFile.nil?) then
				return BRL::Util::FATAL
			end
			writer = BRL::Util::TextWriter.new(@outputFile, "w+", @doGzipOutput)
		  queryCountHash = Hash.new()
		  workPashHit = PashHit.new()
		  retVal = BRL::Util::OK
		  @errMsgs = []
		  # Process each pash file
			if(FileTest.exists?(pashFile))
				reader = BRL::Util::TextReader.new(pashFile)
				reader.each { |line|
					if ( (@recsPerBlock>0) and (reader.lineno > 0) and (reader.lineno % @recsPerBlock == 0)) then
						sleep(rand() + 2.5 + rand(3))
					end
					line.strip!
					if (line.empty?) then
						 next
					end
					$stderr.puts "processing line #{line}" if (CCDEBG)
					ff = line.split(/\t/)
					if (!@queryFirst) then
						queryName = ff[3]
					else
						queryName = ff[3]
					end

					if (queryCountHash.key?(queryName)) then
						queryCountHash[queryName]+=1
					else
						queryCountHash[queryName] = 0
					end
					status = workPashHit.set(line)
					#pashHit = hitNameHash[queryName]
					#if (pashHit.nil?) then
					#	pashHit = PashHit.new()
					#	hitNameHash[queryName] = pashHit
					#end
					#status = pashHit.set(line)
					$stderr.puts "status = #{status}" if (CCDEBG)
					if (status == 1) then
						errMessage = "Incorrect pash line at #{reader.lineno}:"
						$stderr.puts "#{errMessage}:\n#{workPashHit}\n#{workPashHit.message}" if (CCDEBG)
						@errMsgs << "#{errMessage}\n"
						@errMsgs << "#{workPashHit.message.strip}\n\n"
						$stderr.puts "added line conversion error message #{workPashHit.message}" if(CCDEBG)
						if (@errMsgs.size > MAX_NUM_ERRORS) then
							retVal = BRL::Util::FAILED
							break;
						end
					else
						$stderr.puts "about to invoke toLff" if (CCDEBG)
						currentString = workPashHit.toLff(@className, @type, @subtype, queryCountHash[queryName], @queryFirst)
						$stderr.puts "about to print |#{currentString}|" if (CCDEBG)
						writer.print "#{currentString}"
					end
				}
				reader.close()
			else
				@errMsgs << "\nWARNING: File #{pashFile} does not exist. Skipping...\n"
				retVal = BRL::Util::FATAL
			end
			writer.close()
			if (retVal == BRL::Util::OK and @errMsgs.size>0) then
				retVal = BRL::Util::OK_WITH_ERRORS
		  end

			return retVal
		end

		# * *Function*: Processes all the command-line options and dishes them back as a hash.
		# * *Usage*   : <tt>  optsHash = BRL::PASH::PashToLff.processArguments()  </tt>
		# * *Args*    :
		#   - +none+
		# * *Returns* :
		#   - +Hash+  -> Hash of the command-line args with arg names as keys associated with
		#     values. Values can be nil empty string in user gave '' or even nil if user didn't provide
		#     an optional argument.
		# * *Throws*  :
		#   - +none+
		# --------------------------------------------------------------------------
		def Pash2Lff.processArguments()
			# We want to add all the prop_keys as potential command line options
			optsArray =	[	['--inputFile', '-f', GetoptLong::REQUIRED_ARGUMENT],
										['--outputFile', '-o', GetoptLong::OPTIONAL_ARGUMENT],
										['--doGzipOutput', '-z', GetoptLong::OPTIONAL_ARGUMENT],
										['--class', '-c', GetoptLong::OPTIONAL_ARGUMENT],
										['--type', '-t', GetoptLong::OPTIONAL_ARGUMENT],
										['--subtype', '-s', GetoptLong::OPTIONAL_ARGUMENT],
										['--recBlockSize', '-r', GetoptLong::OPTIONAL_ARGUMENT],
										['--queryFirst', '-q', GetoptLong::OPTIONAL_ARGUMENT],
										['--help', '-h', GetoptLong::NO_ARGUMENT]
									]
			progOpts = GetoptLong.new(*optsArray)
			unless(progOpts.getMissingOptions().empty?)
        Pash2Lff.usage("USAGE ERROR: some required arguments are missing")
      end
			optsHash = progOpts.to_hash
			Pash2Lff.usage() if(optsHash.empty? or optsHash.key?('--help'));
			return optsHash
		end

	  # * *Function*: Displays some basic usage info on STDOUT.
	  # * *Usage*   : <tt>  BRL::PASH::PashToLff.usage("WARNING: insufficient info provided")  </tt>
	  # * *Args*    :
	  #   - +String+ ->  Optional message string to output before the usage info.
	  # * *Returns* :
	  #   - +none+
	  # * *Throws*  :
	  #   - +none+
		# --------------------------------------------------------------------------
		def Pash2Lff.usage(msg='')
			unless(msg.empty?)
				puts "\n#{msg}\n"
			end
			puts "
PROGRAM DESCRIPTION:
  Converts Pash output to LFF. Pash output lists regions of the 'query' that
  are mapped to regions of the 'target' followed by score information.

COMMAND LINE ARGUMENTS:
  --inputFile    | -f   => Pash output file to convert to LFF.
  --outputFile   | -o   => [optional] Override the output file location.
                           Default is the inputFileName.lff.
  --doGzipOutput | -z   => [optional flag] Gzip the LFF output file.
                           Adds .gz extension unless you are overriding the output file.
  --class        | -c   => [optional] Override the LFF class value to use.
                           Defaults to 'Pash'.
  --type         | -t   => [optional] Override the LFF type value to use.
                           Defaults to 'Pash'.
  --subtype      | -s   => [optional] Override the LFF subtype value to use.
                           Defaults to 'Hit'.
  --recBlockSize | -r   => [optional] For scalability with other processes, the app will
                           pause 4 sec after seeing this many more lines.
                           Defaults to 16_000 (or no throttling or whatever).
  --queryFirst   | -q   => [optional] The query information occurs before target information.
	                         Defaults to false.
  --help         | -h   => [optional flag] Output this usage info and exit

USAGE:
  pash2lff.rb  -f pash.out.txt -o pash.out.lff

";
			exit(2);
		end # def Pash2Lff.usage(msg='')
	end # Pash2Lff
end ; end # module BRL; module PASH

# ##############################################################################
# MAIN
# ##############################################################################
# Process command line options
$stderr.puts "about to start the converter at #{Time.now()}"
optsHash = BRL::PASH::Pash2Lff.processArguments()
# Instantiate converter using program arguments
converter = BRL::PASH::Pash2Lff.new(optsHash)
# Convert
exitVal = converter.convertPashFiles()
if(exitVal == BRL::Util::FAILED)
  errStr =  "ERROR: Too many errors while coverting Pash hits to LFF annotations.\n" +
            "Please check that you really have an actual Pash output file.\n\n" +
            "Here is a sample of the formatting errors detected:\n" + ('-'*40) + "\n\n"
  $stderr.print errStr
  msgSize = errStr.size
  msgCount = 0
  converter.errMsgs.each { |msg|
    msgSize += msg.size
    msgCount += 1
    break if(msgSize > BRL::PASH::MAX_EMAIL_SIZE or msgCount > BRL::PASH::MAX_EMAIL_ERRS)
    $stderr.puts msg
  }
elsif(exitVal == BRL::Util::OK_WITH_ERRORS)
  errStr =  "WARNING: some of your Pash data was badly formatted and thus ignored.\n\n" +
            "Here is a sample of the formatting errors detected:\n" + ('-'*40) + "\n\n"
  $stderr.print errStr
  msgSize = errStr.size
  msgCount = 0
  converter.errMsgs.each { |msg|
    msgSize += msg.size
    msgCount += 1
    break if(msgSize > BRL::PASH::MAX_EMAIL_SIZE or msgCount > BRL::PASH::MAX_EMAIL_ERRS)
    $stderr.puts msg
  }
end

exit(exitVal)
