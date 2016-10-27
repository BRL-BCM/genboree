#!/usr/bin/env ruby

# ##############################################################################
# REQUIRED LIBRARIES
# ##############################################################################
require 'brl/util/textFileUtil' # For TextReader/Writer convenience classes
require 'dbi'
require 'brl/db/dbrc'						# For brl/db/DBRC class and database nicities
require 'brl/db/util'
require 'brl/keyword/keywordPGIUtil.rb'
# ##############################################################################
# Turn on extra warnings and such
$VERBOSE = true

module LoadPGIIndices
	def LoadPGIIndices.processArguments
		progOpts =
			GetoptLong.new(
				['--experimentStr', '-e', GetoptLong::REQUIRED_ARGUMENT],
				['--pgiDatabaseName', '-d', GetoptLong::REQUIRED_ARGUMENT],
				['--minIndexOrder', '-m', GetoptLong::REQUIRED_ARGUMENT],
				['--help', '-h', GetoptLong::NO_ARGUMENT]
			)

		optsHash = progOpts.to_hash
		LoadPGIIndices.usage() if(optsHash.empty? or optsHash.key?('--help'));
		return optsHash
	end

	def LoadPGIIndices.usage(msg='')
		unless(msg.empty?)
			puts "\n#{msg}\n"
		end
		puts "

	PROGRAM DESCRIPTION:

	COMMAND LINE ARGUMENTS:
	-e    => PGI experiment-to-import's ID string
	-d    => pgi database name (in case you have several)
	-m    => minimum index order to import (recommend 3 or greater)
	-h    => [optional flag] Output this usage info and exit

  NOTE: your DB_ACCESS_FILE environmental file should be properly set to point
        to your personal .dbrc file. Otherwise, forget it.

	USAGE:
	loadPGIIndicesFromDatabase.rb -e \"PGI-1-RM-CH250-HG-HG13\" -d andrewj_pgi -m 3

	";
		exit(2);
	end
end # module LoadPGIIndices

# ##############################################################################
# MAIN
# ##############################################################################
# get the DBRC file to use
dbrcFile = ENV['DB_ACCESS_FILE'] || '~/.dbrc'

# process command line options
optsHash = LoadPGIIndices.processArguments()

# create instance of our entrypoint helper that will do all the work
entrypointUtil = BRL::Keyword::KeywordPGIUtil.new(optsHash['--pgiDatabaseName'], optsHash['--experimentStr'], dbrcFile)

# load the file into the database!
entrypointUtil.importFromPGITables(optsHash['--minIndexOrder'])

exit(0);
