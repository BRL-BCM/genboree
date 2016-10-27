#!/usr/bin/env ruby

=begin

=end
# ##############################################################################
# REQUIRED LIBRARIES
# #############################################################################
require 'brl/util/util'
require 'brl/util/textFileUtil'
require 'GSL'

SHUFFDIRBASE = "/home/po4a/brl/poolData/Rhesus.macaque/hg15-29-5-2003/deconvolutions/3-6-2003/CONFIRM_shuffling/shuffling"
OUTDIR = "/home/po4a/brl/poolData/Rhesus.macaque/hg15-29-5-2003/deconvolutions/3-6-2003/CONFIRM_shuffling/"
FOUR_POOL, THREE_POOL, TWO_POOL = 0,1,2

confirmed4PoolBacPercentages = []
confirmed3PoolBacPercentages = []
confirmedOverallBacPercentages = []
confirmedHighConfIndexPercentages = []
confirmedMedConfIndexPercentages = []
confirmedLowConfIndexPercentages = []
confirmedGoodIndexPercentages = []

shuffleFiles = Dir.glob("#{SHUFFDIRBASE}*/categorizeBacs.out")

shuffleFiles.each {
	|fileName|
	bacsWithGoodIndices = [ 0,0 ]
	bacsWithConfirmedIndices = [ 0,0 ]
	numIndices = [ 0,0,0 ]
	numConfirmedIndices = [ 0,0,0 ]

	file = BRL::Util::TextReader.new(fileName)
	file.each {
		|line|
		if(line =~ /^\s*$/)
			next
		elsif(line =~ /^\s+Control Bacs With 4 Pools, Having  1\+ of at least order 3 Indices:\s+(\d+)/)
			bacsWithGoodIndices[FOUR_POOL] = $1.to_f
		elsif(line =~ /^\s+Control Bacs With 3 Pools, Having  1\+ of at least order 3 Indices:\s+(\d+)/)
			bacsWithGoodIndices[THREE_POOL] = $1.to_f
		elsif(line =~ /^\s+Control Bacs With 4 Pools, Having 1\+ of at least order 3 Confirmed Indices:\s+(\d+)/)
			bacsWithConfirmedIndices[FOUR_POOL] = $1.to_f
		elsif(line =~ /^\s+Control Bacs With 3 Pools Having 1\+ of at least order 3 Confirmed Indices:\s+(\d+)/)
			bacsWithConfirmedIndices[THREE_POOL] = $1.to_f
		elsif(line =~ /^\s+Indices Involving 4 Pools Amongst Control BACs:\s+(\d+)/)
			numIndices[FOUR_POOL] = $1.to_f
		elsif(line =~ /^\s+Indices Involving 3 Pools Amongst Control BACs:\s+(\d+)/)
			numIndices[THREE_POOL] = $1.to_f
		elsif(line =~ /^\s+Indices Involving 2 Pools Amongst Control BACs:\s+(\d+)/)
			numIndices[TWO_POOL] = $1.to_f
		elsif(line =~ /^\s+Confirmed Indices Involving 4 Pools Amongst Control BACs:\s+(\d+)/)
			numConfirmedIndices[FOUR_POOL] = $1.to_f
		elsif(line =~ /^\s+Confirmed Indices Involving 3 Pools Amongst Control BACs:\s+(\d+)/)
			numConfirmedIndices[THREE_POOL] = $1.to_f
		elsif(line =~ /^\s+Confirmed Indices Involving 2 Pools Amongst Control BACs:\s+(\d+)/)
			numConfirmedIndices[TWO_POOL] = $1.to_f
		else
			next
		end
	}
	(confirmed4PoolBacPercentages << (bacsWithConfirmedIndices[FOUR_POOL].to_f / bacsWithGoodIndices[FOUR_POOL].to_f)) if(bacsWithGoodIndices[FOUR_POOL] > 0)
	(confirmed3PoolBacPercentages << (bacsWithConfirmedIndices[THREE_POOL].to_f / bacsWithGoodIndices[THREE_POOL].to_f)) if(bacsWithGoodIndices[THREE_POOL] > 0)
	(confirmedOverallBacPercentages << (bacsWithConfirmedIndices[FOUR_POOL].to_f / bacsWithGoodIndices[FOUR_POOL].to_f)) if(bacsWithGoodIndices[FOUR_POOL] > 0)
	(confirmedOverallBacPercentages << (bacsWithConfirmedIndices[THREE_POOL].to_f / bacsWithGoodIndices[THREE_POOL].to_f)) if(bacsWithGoodIndices[THREE_POOL] > 0)
	(confirmedHighConfIndexPercentages << (numConfirmedIndices[FOUR_POOL].to_f / numIndices[FOUR_POOL].to_f)) if(numIndices[FOUR_POOL] > 0)
	(confirmedMedConfIndexPercentages << (numConfirmedIndices[THREE_POOL].to_f / numIndices[THREE_POOL].to_f)) if(numIndices[THREE_POOL] > 0)
	(confirmedLowConfIndexPercentages << (numConfirmedIndices[TWO_POOL].to_f / numIndices[TWO_POOL].to_f)) if(numIndices[TWO_POOL] > 0)
	(confirmedGoodIndexPercentages << (numConfirmedIndices[FOUR_POOL].to_f / numIndices[FOUR_POOL].to_f)) if(numIndices[FOUR_POOL] > 0)
	(confirmedGoodIndexPercentages << (numConfirmedIndices[THREE_POOL].to_f / numIndices[THREE_POOL].to_f)) if(numIndices[THREE_POOL] > 0)
}

puts "4-Pool Bac confirmation rates of indices of order 3 or 4:"
puts confirmed4PoolBacPercentages
puts '-' * 40

puts "3-Pool Bac confirmation rates of indices of order 3 or 4:"
puts confirmed3PoolBacPercentages
puts '-' * 40

puts "4-Pool or 3-pool Bac confirmation rates of indices of order 3 or 4:"
puts confirmedOverallBacPercentages
puts '-' * 40

puts "High-conf index confirmation rates:"
puts confirmedHighConfIndexPercentages
puts '-' * 40

puts "Med-conf index confirmation rates:"
puts confirmedMedConfIndexPercentages
puts '-' * 40

puts "Low-conf index confirmation rates:"
puts confirmedLowConfIndexPercentages
puts '-' * 40

puts "Believable index confirmation rates:"
puts confirmedGoodIndexPercentages
puts '-' * 40
