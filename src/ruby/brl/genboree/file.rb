#!/usr/bin/env ruby
require 'brl/util/textFileUtil'
require 'brl/util/util'


class LffIntersect
  DEBUG = true
  attr_accessor :exeStatus

  def initialize(optsHash)
		@optsHash = optsHash
		@exeStatus = 0
		setParameters()
	end

  def setParameters()
		@firstTrack = " -f #{CGI.escape(@optsHash['--firstOperandTrack'])} "
		@secondTrack =" -I #{CGI.escape(@optsHash['--secondOperandTrack'])} "
		@listOfLffFiles = " -l #{CGI.escape(@optsHash['--listOfLffFiles'])} "
		@outputFile = " -o #{CGI.escape(@optsHash['--outputFile'])} "
		@newTrack = " -n #{CGI.escape(@optsHash['--newTrack'])} "
		if (@optsHash.key?('--newClass')) then
			@newClass = " -c #{CGI.escape(@optsHash['--newClass'])} "
		else
			@newClass = " "
		end
		if (@optsHash.key?('--radius')) then
			@radius = " -r #{@optsHash['--radius']} "
		else
			@radius = " "
		end
		if (@optsHash.key?('--minTracks')) then
			@minTracks = " -m #{@optsHash['--minTracks']} "
		else
			@minTracks =" "
		end
		if (@optsHash.key?('--allTracks')) then
			@allTracks = " -a "
		else
			@allTracks =" "
		end
  end

  def work()
		lffIntersectExeCommand = "lffIntersect.exe "
		lffIntersectExeCommand << @firstTrack << @secondTrack << @listOfLffFiles << @outputFile
		lffIntersectExeCommand << @newTrack << @newClass << @radius << @minTracks << @allTracks

		$stderr.puts "#{Time.now()} RUBY - TRACK OP: Executing command #{lffIntersectExeCommand}"
		exeOut = `#{lffIntersectExeCommand} 2>&1 `
		@exeStatus = $?.exitstatus + ($?.exitstatus == 0 ? 0 : 50) # 0,1,2,3 have reserved meanings, so add 50 unless it was 0 (success)
		$stderr.puts "#{Time.now()} RUBY - TRACK OP: : .exe command is done with exit status '#{$?.exitstatus}' which will be returned from this wrapper as '#{@exeStatus}'. Its stdout was:\n#{exeOut}"
  end

  def LffIntersect.processArguments()
		# We want to add all the prop_keys as potential command line options
		optsArray =	[ ['--firstOperandTrack',     '-f', GetoptLong::REQUIRED_ARGUMENT],
									['--secondOperandTrack',    '-s', GetoptLong::REQUIRED_ARGUMENT],
									['--listOfLffFiles',   		  '-l', GetoptLong::REQUIRED_ARGUMENT],
									['--outputFile',    				'-o', GetoptLong::REQUIRED_ARGUMENT],
									['--newTrack',              '-n', GetoptLong::REQUIRED_ARGUMENT],
									['--newClass',    					'-c', GetoptLong::OPTIONAL_ARGUMENT],
									['--radius',   		  				'-r', GetoptLong::OPTIONAL_ARGUMENT],
									['--minTracks',   		  		'-m', GetoptLong::OPTIONAL_ARGUMENT],
									['--allTracks',   		  		'-a', GetoptLong::NO_ARGUMENT],
									['--noValidation',   		  	'-V', GetoptLong::NO_ARGUMENT],
									['--help',           '-h', GetoptLong::NO_ARGUMENT]
								]

		progOpts = GetoptLong.new(*optsArray)
		optsHash = progOpts.to_hash
		LffIntersect.usage() if(optsHash.key?('--help'));

		unless(progOpts.getMissingOptions().empty?)
			LffIntersect.usage("USAGE ERROR: some required arguments are missing")
		end

		LffIntersect.usage() if(optsHash.empty?);
		return optsHash
	end

	def LffIntersect.usage(msg='')
			unless(msg.empty?)
				puts "\n#{msg}\n"
			end
			puts "
  PROGRAM DESCRIPTION:
    Given a list of LFF files and two operand tracks, outputs an LFF file
    containing only those annotations from the first operand that overlap with
    at least one annotation from the second operand track.

    Actually, it's a bit more general in that it supports *multiple* second
    operand tracks, so you can have it output annotations from the first
    operand track that overlap with an annotation from *any* of the other
    operand tracks. Saves a bit of time and is more useful for certain use
    cases (eg, my ESTs that intersect with ESTs from any one of various cancer
    libraries). This is OPTIONAL.

		By default, first operand track annotations are output if they intersect
		*any* of the other operand tracks. But if you use -a, you can require
		intersection with *all* of the other operand tracks before a first operand
		track is accepted. This is OPTIONAL.

    Furthermore, you can also tell it a minimum number of intersections be
    found before outputting the record. (eg, my ESTs that intersect with at
    least 3 ESTs from any one of various cancer libraries). If you have
    also specified -a (see above), then *all* tracks must have at least this
    number of intersections with a first operand track annotation for it to be
    accepted. This is OPTIONAL.

    You can even provide a radius--this is a fixed number of base pairs that
    will be added to the ends of your records in the first operand track when
    determining intersection. This allows smaller ('point mappings') to be
    treated as bigger than they are. Good for treating PGI indices as BACs or
    something.

    Track names follow this convention, as displayed in Genboree:
       Type:SubType
    That is to say, the track Type and its Subtype are separated by a colon, to
    form the track name. This format is *required* when identifying tracks.

    The --lffFiles (or -l) option, the --otherOperandTracks (or -o) option,
    support both a single name or a comma-separated list of names. Enclosing
    in quotes is often a good practice, but shouldn't be required.

    NOTE: it is HIGHLY recommended to URL escape argument values. This will take
    care of any special characters such as spaces, quotes, etc. Also, escaping
    file paths will ensure that paths that are constructed using escaped strings
    (for safe file/directory names) are properly double-escaped.

    COMMAND LINE ARGUMENTS:
      -f    => Name of the first operand track. You will be precipitating out
               annotations from this track that overlap with annotations from
               the other track(s).
      -s    => Name(s) of the second operand track(s). If you specify more than
               one, then an annotation in the first track overlay an
               annotation in *any* of these tracks will be output.
      -l    => A list of LFF files where annotations can be found to work on.
               Annotations with irrelevant track names will be ignored and not
               output.
      -o    => Name of output file in which to put data.
      -n    => New track name for annotations having intersection.
               Should be in form of type:subtype.
      -c    => [optional] Class for new track.
      -r    => [optional] Add this radius to make annotations a bit 'larger'
               when considering overlap. Thus, the annotations may not strictly
               overlap, but may be really close to overlapping. Default is 0.
      -a    => [optional] This will require intersect with at least a minimum
               (see -m below) number of annotations from *each* track listed
               with -s. That is to say, 'AND' rather than 'OR', or insection
               with 'ALL' second operand tracks rather than just any track.
      -m    => [optional] Minimum number of interections a record in the first
               operand track must have to be output. Default is 1. If -a is
               used, then ALL second operand tracks must have at least this
               number of intersecting annotations for the first operand
               annotation to be output.
      -V    => [optional flag] Turns OFF lff record validation. For use when
               Genboree is calling this program. Saves time, in theory.
      -h    => [optional flag] Output this usage info and exit.

    USAGE:
    lffIntersect.rb -f ESTs%3AUt1 -s Gene%3ARefSeq%2CGene%3AEns -l \
     ./myData.lff -o myInterData.lff -n ESTs%3AwGenes
			";
			exit(134);
	end
end


########################################################################################
# MAIN
########################################################################################

# Process command line options
optsHash = LffIntersect.processArguments()
# Instantiate analyzer using the program arguments
lffIntersecter = LffIntersect.new(optsHash)
# Analyze this !
lffIntersecter.work()
exit(lffIntersecter.exeStatus)
