#!/usr/bin/env ruby
=begin
=end
# ##############################################################################
# $Copyright:$
# ##############################################################################
# ##############################################################################
# REQUIRED CLASSES/MODULES
# ##############################################################################
require 'GSL'
require 'brl/util/util'
require 'brl/util/textFileUtil'

# Arguments
unless(ARGV.size >1)
	$stderr.puts "\n\nUSAGE: randShuffle_1Chr.rb <linearizedChrFile> <chunkSize>\n\n"
	exit(134)
end
chrFile = File.open(ARGV[0])
chunkSize = ARGV[1].to_i

# Read 2 lines from linearized chr file
defLine = chrFile.readline
seq = chrFile.readline.chomp
$stderr.puts "\nSTATUS: read in 1 linearized chromosome with #{seq.size} bases"

# How many chunks will we need?
numChunks = (seq.size / chunkSize.to_f).ceil
$stderr.puts "\nSTATUS: need to make #{numChunks} chunks"
chunks = Array.new(numChunks)

# Make the chunks
numChunks.times { |ii| chunks[ii] = ii }
# Shuffle the chunks array
rng = GSL::Random::RNG.new
chunks.shuffle(rng)
$stderr.puts "\nSTATUS: shuffled chunk order (shuffled array has #{chunks.size} chunks)"
# We need to RECORD the chunk order. All we need is the order of original chunks
# in the rearranged chromosome.
writer = BRL::Util::TextWriter.new("#{ARGV[0]}.SHUFFLED_CHUNK_ORDER")
writer.puts chunks.join("\n")
writer.close

$stderr.puts "\nSTAT
# Print the chunks
puts "#{defLine.chomp} SHUFFLED"
$stderr.puts "DOING CHUNKS:"
chunks.each { |xx|
	$stderr.print xx
	chunkStart = (xx * chunkSize)
	$stderr.print "\tstart: #{chunkStart}"
	print seq[chunkStart, chunkSize]
}
$stderr.puts "\nSTATUS: done dumping new shuffled genome"
exit(0)
