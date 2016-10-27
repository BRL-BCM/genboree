#!/usr/bin/env ruby

# ##############################################################################
# REQUIRED LIBRARIES
# ##############################################################################
require 'brl/util/textFileUtil' # For TextReader/Writer convenience classes
require 'dbi'
require 'brl/db/dbrc'						# For brl/db/DBRC class and database nicities
require 'brl/db/util'
require 'brl/keyword/keywordEntrypointUtil.rb'
# ##############################################################################
# Turn on extra warnings and such
$VERBOSE = true

module LoadEntrypoints
	def LoadEntrypoints.processArguments
		progOpts =
			GetoptLong.new(
				['--entrypointFile', '-f', GetoptLong::REQUIRED_ARGUMENT],
				['--help', '-h', GetoptLong::NO_ARGUMENT]
			)

		optsHash = progOpts.to_hash
		LoadEntrypoints.usage() if(optsHash.empty? or optsHash.key?('--help'));
		return optsHash
	end

	def LoadEntrypoints.usage(msg='')
		unless(msg.empty?)
			puts "\n#{msg}\n"
		end
		puts "

	PROGRAM DESCRIPTION:

	COMMAND LINE ARGUMENTS:
	-f		=> Location of the file with the LDAS header data describing entrypoints (top level only for now)
	-h    => [optional flag] Output this usage info and exit

  NOTE: your DB_ACCESS_FILE environmental file should be properly set to point
        to your personal .dbrc file. Otherwise, forget it.

	USAGE:
	loadEntrypoints.rb -f someFile

	";
		exit(2);
	end
end # module LoadEntrypoints

# ##############################################################################
# MAIN
# ##############################################################################
# get the DBRC file to use
dbrcFile = ENV['DB_ACCESS_FILE'] || '~/.dbrc'

# process command line options
optsHash = LoadEntrypoints.processArguments()

# create instance of our entrypoint helper that will do all the work
entrypointUtil = BRL::Keyword::KeywordEntrypointUtil.new(dbrcFile)

# load the file into the database!
entrypointUtil.importFromLDASFile(optsHash['--entrypointFile'])

exit(0);