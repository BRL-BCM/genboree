#!/usr/bin/env ruby
$VERBOSE = 1

class GapElement
	attr_accessor :block1, :block2, :start, :stop, :length, :orientation
	def initialize()
		@block1 = nil
		@block2 = nil
		@start = 0
		@stop = 0
		@length = nil
		@orientation = nil
	end
end

class Gap
	attr_accessor :adjacency, :genome1, :genome2
	def initialize(genome1, genome2, adjacency)
		@hashGap = Hash.new
		@hashGap[genome1] = GapElement.new
		@hashGap[genome2] = GapElement.new
		@adjacency = adjacency
		@genome1 = genome1
		@genome2 = genome2
	end

	def block1 (genome, value=nil)
		if (value.nil?)
			return @hashGap[genome].block1
		else
			@hashGap[genome].block1 = value
		end
	end

	def block2 (genome, value=nil)
		if (value.nil?)
			return @hashGap[genome].block2
		else
			@hashGap[genome].block2 = value
		end
	end

	def start (genome, value=nil)
		if (value.nil?)
			return @hashGap[genome].start
		else
			@hashGap[genome].start = value
		end
	end

	def stop (genome, value=nil)
		if (value.nil?)
			return @hashGap[genome].stop
		else
			@hashGap[genome].stop = value
		end
	end

	def length (genome, value=nil)
		if (value.nil?)
			return @hashGap[genome].length
		else
			@hashGap[genome].length = value
		end
	end

	def orientation (genome, value=nil)
		if (value.nil?)
			return @hashGap[genome].orientation
		else
			@hashGap[genome].orientation = value
		end
	end
	
	def findOrientation (block1Strand, block2Strand)
		orientation = ""
		
		if (block1Strand == block2Strand)
			orientation = "+"
		else
			orientation = "-"
		end
		
		return orientation
	end
	
	def input(genome, block1, block2, start, stop, block1Strand, block2Strand, length=nil)
		@hashGap[genome].block1 = block1
		@hashGap[genome].block2 = block2
		@hashGap[genome].start = start
		@hashGap[genome].stop = stop
		@hashGap[genome].orientation = self.findOrientation(block1Strand, block2Strand)
		if (length.nil?)
			@hashGap[genome].length = stop.to_i - start.to_i
		else
			@hashGap[genome].length = length
		end
	end

	def output(number)
		@hashGap.each do |genome, gapElement|
			puts "#{gapElement.block1.gsub(/\.\d+/,"")}-#{gapElement.block2.gsub(/\.\d+/,"")}\t#{number}\t#{genome}\t#{@adjacency}\t#{gapElement.length}\t#{gapElement.orientation}"
		end
	end
end

def findNonAdjacentBlock(hashBlockSet, otherGenome, blockNumber)
	#calculate start and stop of gap element based on nonadjacent bounding blocks
	nonAdjacentBlockElement = nil
	targetAdjacentBlockElement = nil
	arrBlockElements.each do |testBlockElement|
		unless (testBlockElement['subtype'] == blockElement['subtype'])
			nonAdjacentBlockElement = testBlockElement
			
			hashBlockSet[blockNumber].each do |testTargetAdjacentBlockElement|
				if (testTargetAdjacentBlockElement['subtype'] == testBlockElement['subtype'])
					targetAdjacentBlockElement = testTargetAdjacentBlockElement
				end
			end
		end
	end
end

require 'brl/util/textFileUtil'
require 'brl/util/util'

reader = BRL::Util::TextReader.new(ARGV[0])

hashBlockSet = Hash.new()

reader.each do
	| line |
	
	line.strip!
	
	arrSplit = line.split(/\t/)

	hashBlockElement = Hash.new
	hashBlockElement['className'] = arrSplit[0]
	hashBlockElement['name'] = arrSplit[1].gsub(/\.\d+$/,"")
	hashBlockElement['type'] = arrSplit[2]
	hashBlockElement['subtype'] = arrSplit[3]
	hashBlockElement['chrom'] = arrSplit[4]
	hashBlockElement['start'] = arrSplit[5].to_i
	hashBlockElement['stop'] = arrSplit[6].to_i
	hashBlockElement['strand'] = arrSplit[7]
	hashBlockElement['phase'] = arrSplit[8]
	hashBlockElement['score'] = arrSplit[9].to_i
	hashBlockElement['targetStart'] = arrSplit[10]
	hashBlockElement['targetStop'] = arrSplit[11]
	
	species = hashBlockElement['subtype'].gsub(/-.+/,"")
	hashBlockElement['species'] = species

	nameSplit = arrSplit[1].split(".")
	block = nameSplit[nameSplit.length - 1].to_i

	hashBlockElement['block'] = block
	
	if (hashBlockSet.has_key?(block))
		hashBlockSet[block].push(hashBlockElement)
	else
		hashBlockSet[block] = Array.new
		hashBlockSet[block].push(hashBlockElement)
	end
end

count = 1
adjacentBlockElement = nil
start = nil
stop = nil
length = nil
orientation = nil
hashGapSet = Hash.new

sortedHashBlockSet = hashBlockSet.sort
sortedHashBlockSet.each do |block, arrBlockElements|
	if (arrBlockElements.length == 2)
		hashAdjacentBlocks = Hash.new
		# Find adjacent elements and blocks
		arrBlockElements.each do |blockElement|
			adjacentBlockElementStart = 1000000000
			prevBlockElementStop = -1
			hashBlockSet.each do |targetBlock, arrTargetBlockElements|
				unless (block == targetBlock)
					arrTargetBlockElements.each do |nonAdjacentBlockElement|
						#The target block is the next block (upstream)
						if (blockElement['subtype'] == nonAdjacentBlockElement['subtype']) && (blockElement['chrom'] == nonAdjacentBlockElement['chrom']) && ((nonAdjacentBlockElement['start'] > blockElement['stop']) && (nonAdjacentBlockElement['start'] < adjacentBlockElementStart))
							if (hashAdjacentBlocks.has_key?(nonAdjacentBlockElement['subtype']))
								hashAdjacentBlocks[nonAdjacentBlockElement['subtype']]['next'] = nonAdjacentBlockElement
							else
								hashAdjacentBlocks[nonAdjacentBlockElement['subtype']] = Hash.new
								hashAdjacentBlocks[nonAdjacentBlockElement['subtype']]['next'] = nonAdjacentBlockElement
							end
							adjacentBlockElementStart = nonAdjacentBlockElement['start']
						#The target block is the previous block (downstream)
						elsif (blockElement['subtype'] == nonAdjacentBlockElement['subtype']) && (blockElement['chrom'] == nonAdjacentBlockElement['chrom']) && ((nonAdjacentBlockElement['stop'] < blockElement['start']) && (nonAdjacentBlockElement['stop'] > prevBlockElementStop))
							if (hashAdjacentBlocks.has_key?(nonAdjacentBlockElement['subtype']))
								hashAdjacentBlocks[nonAdjacentBlockElement['subtype']]['prev'] = nonAdjacentBlockElement
							else
								hashAdjacentBlocks[nonAdjacentBlockElement['subtype']] = Hash.new
								hashAdjacentBlocks[nonAdjacentBlockElement['subtype']]['prev'] = nonAdjacentBlockElement
							end
							prevBlockElementStop = nonAdjacentBlockElement['stop']
						end
					end
				end
			end
		end
		
		unless (hashAdjacentBlocks[arrBlockElements[0]['subtype']].nil? || hashAdjacentBlocks[arrBlockElements[1]['subtype']].nil?)
			
			#-----------------------------------------------------------------
			#Next and previous not nil in either genome
			#-----------------------------------------------------------------
			if (!hashAdjacentBlocks[arrBlockElements[0]['subtype']]['prev'].nil? && !hashAdjacentBlocks[arrBlockElements[1]['subtype']]['prev'].nil?) && (!hashAdjacentBlocks[arrBlockElements[0]['subtype']]['next'].nil? && !hashAdjacentBlocks[arrBlockElements[1]['subtype']]['next'].nil?)
				
				#NOT REARRANGED
				#previous - arrBlockElements[0] - next
				#    =               =             =
				#previous - arrBlockElements[1] - next
				if (hashAdjacentBlocks[arrBlockElements[0]['subtype']]['prev']['block'] == hashAdjacentBlocks[arrBlockElements[1]['subtype']]['prev']['block']) && (hashAdjacentBlocks[arrBlockElements[0]['subtype']]['next']['block'] == hashAdjacentBlocks[arrBlockElements[1]['subtype']]['next']['block'])
					gap1 = Gap.new(arrBlockElements[0]['subtype'], arrBlockElements[1]['subtype'], "AdjacentInBoth")
					gap2 = Gap.new(arrBlockElements[0]['subtype'], arrBlockElements[1]['subtype'], "AdjacentInBoth")
					
					arrBlockElements.each do |blockElement|
						#previous - arrBlockElement
						adjacentBlockElement = hashAdjacentBlocks[blockElement['subtype']]['prev']
						gap1.input(blockElement['subtype'], blockElement['name'], adjacentBlockElement['name'], adjacentBlockElement['stop'] + 1, blockElement['start'] - 1, blockElement['strand'], adjacentBlockElement['strand'])
	
						#arrBlockElement - next
						adjacentBlockElement = hashAdjacentBlocks[blockElement['subtype']]['next']
						gap2.input(blockElement['subtype'], blockElement['name'], adjacentBlockElement['name'], blockElement['stop'] + 1, adjacentBlockElement['start'] - 1, blockElement['strand'], adjacentBlockElement['strand'])
					end
					
					hashGapSet[count] = gap1
					count += 1
					
					hashGapSet[count] = gap2
					count += 1
				
				#NOT REARRANGED
				#previous - arrBlockElements[0] - next
				#    =               =             =
				#next     - arrBlockElements[1] - previous
				elsif (hashAdjacentBlocks[arrBlockElements[0]['subtype']]['prev']['block'] == hashAdjacentBlocks[arrBlockElements[1]['subtype']]['next']['block']) && (hashAdjacentBlocks[arrBlockElements[0]['subtype']]['next']['block'] == hashAdjacentBlocks[arrBlockElements[1]['subtype']]['prev']['block'])
					gap1 = Gap.new(arrBlockElements[0]['subtype'], arrBlockElements[1]['subtype'], "AdjacentInBoth")
					gap2 = Gap.new(arrBlockElements[0]['subtype'], arrBlockElements[1]['subtype'], "AdjacentInBoth")
					
					arrBlockElements.each do |blockElement|
						if (blockElement['subtype'] == arrBlockElements[0]['subtype'])
							#previous - arrBlockElement[0]
							adjacentBlockElement = hashAdjacentBlocks[blockElement['subtype']]['prev']
							gap1.input(blockElement['subtype'], blockElement['name'], adjacentBlockElement['name'], adjacentBlockElement['stop'] + 1, blockElement['start'] - 1, blockElement['strand'], adjacentBlockElement['strand'])
		
							#arrBlockElement[0] - next
							adjacentBlockElement = hashAdjacentBlocks[blockElement['subtype']]['next']
							gap2.input(blockElement['subtype'], blockElement['name'], adjacentBlockElement['name'], blockElement['stop'] + 1, adjacentBlockElement['start'] - 1, blockElement['strand'], adjacentBlockElement['strand'])
						elsif (blockElement['subtype'] == arrBlockElements[1]['subtype'])
							#next - arrBlockElement[1]
							adjacentBlockElement = hashAdjacentBlocks[blockElement['subtype']]['next']
							gap1.input(blockElement['subtype'], blockElement['name'], adjacentBlockElement['name'], blockElement['stop'] + 1, adjacentBlockElement['start'] - 1, blockElement['strand'], adjacentBlockElement['strand'])
		
							#arrBlockElement[1] - prev
							adjacentBlockElement = hashAdjacentBlocks[blockElement['subtype']]['prev']
							gap2.input(blockElement['subtype'], blockElement['name'], adjacentBlockElement['name'], adjacentBlockElement['stop'] + 1, blockElement['start'] - 1, blockElement['strand'], adjacentBlockElement['strand'])
						end
					end
					
					hashGapSet[count] = gap1
					count += 1
					
					hashGapSet[count] = gap2
					count += 1
				
				#REARRANGED 1
				#previous | arrBlockElements[0] - next
				#                  =             =
				#previous | arrBlockElements[1] - next
				elsif (hashAdjacentBlocks[arrBlockElements[0]['subtype']]['prev']['block'] != hashAdjacentBlocks[arrBlockElements[1]['subtype']]['prev']['block']) && (hashAdjacentBlocks[arrBlockElements[0]['subtype']]['next']['block'] == hashAdjacentBlocks[arrBlockElements[1]['subtype']]['next']['block'])
					gap1_0 = Gap.new(arrBlockElements[0]['subtype'], arrBlockElements[1]['subtype'], "AdjacentIn#{arrBlockElements[0]['species']}Only")
					gap1_1 = Gap.new(arrBlockElements[0]['subtype'], arrBlockElements[1]['subtype'], "AdjacentIn#{arrBlockElements[1]['species']}Only")
					gap2 = Gap.new(arrBlockElements[0]['subtype'], arrBlockElements[1]['subtype'], "AdjacentInBoth")
					
					arrBlockElements.each do |blockElement|
						if (blockElement['subtype'] == arrBlockElements[0]['subtype'])
							#previous - arrBlockElement[0]
							adjacentBlockElement = hashAdjacentBlocks[blockElement['subtype']]['prev']
							gap1_0.input(blockElement['subtype'], blockElement['name'], adjacentBlockElement['name'], adjacentBlockElement['stop'] + 1, blockElement['start'] - 1, blockElement['strand'], adjacentBlockElement['strand'])
							
							#Other non-adjacent genome
							nonAdjacentBlockElement = hashBlockSet[adjacentBlockElement['block']][1]
							
							#calculate start and stop of non-adjacent elements
							if (arrBlockElements[1]['chrom'] == nonAdjacentBlockElement['chrom'])
								if (arrBlockElements[1]['start'] > nonAdjacentBlockElement['stop'])
									start = nonAdjacentBlockElement['stop'] + 1
									stop = arrBlockElements[1]['start'] - 1
								else
									start = arrBlockElements[1]['stop'] + 1
									stop = nonAdjacentBlockElement['start'] - 1
								end
								
								gap1_0.input(arrBlockElements[1]['subtype'], arrBlockElements[1]['name'], nonAdjacentBlockElement['name'], start, stop, arrBlockElements[1]['strand'], nonAdjacentBlockElement['strand'])
							else
								gap1_0.input(arrBlockElements[1]['subtype'], arrBlockElements[1]['name'], nonAdjacentBlockElement['name'], 0, 0, arrBlockElements[1]['strand'], nonAdjacentBlockElement['strand'], "INF")
							end
							
							#arrBlockElement[0] - next
							adjacentBlockElement = hashAdjacentBlocks[blockElement['subtype']]['next']
							gap2.input(blockElement['subtype'], blockElement['name'], adjacentBlockElement['name'], blockElement['stop'] + 1, adjacentBlockElement['start'] - 1, blockElement['strand'], adjacentBlockElement['strand'])
						elsif (blockElement['subtype'] == arrBlockElements[1]['subtype'])
							#prev - arrBlockElement[1]
							adjacentBlockElement = hashAdjacentBlocks[blockElement['subtype']]['prev']
							gap1_1.input(blockElement['subtype'], blockElement['name'], adjacentBlockElement['name'], adjacentBlockElement['stop'] + 1, blockElement['start'] - 1, blockElement['strand'], adjacentBlockElement['strand'])
							
							#Other non-adjacent genome
							nonAdjacentBlockElement = hashBlockSet[adjacentBlockElement['block']][0]
							
							#calculate start and stop of non-adjacent elements
							if (arrBlockElements[0]['chrom'] == nonAdjacentBlockElement['chrom'])
								if (arrBlockElements[0]['start'] > nonAdjacentBlockElement['stop'])
									start = nonAdjacentBlockElement['stop'] + 1
									stop = arrBlockElements[0]['start'] - 1
								else
									start = arrBlockElements[0]['stop'] + 1
									stop = nonAdjacentBlockElement['start'] - 1
								end
								
								gap1_1.input(arrBlockElements[0]['subtype'], arrBlockElements[0]['name'], nonAdjacentBlockElement['name'], start, stop, arrBlockElements[0]['strand'], nonAdjacentBlockElement['strand'])
							else
								gap1_1.input(arrBlockElements[0]['subtype'], arrBlockElements[0]['name'], nonAdjacentBlockElement['name'], 0, 0, arrBlockElements[0]['strand'], nonAdjacentBlockElement['strand'], "INF")
							end
							
							#arrBlockElement[1] - next
							adjacentBlockElement = hashAdjacentBlocks[blockElement['subtype']]['next']
							gap2.input(blockElement['subtype'], blockElement['name'], adjacentBlockElement['name'], blockElement['stop'] + 1, adjacentBlockElement['start'] - 1, blockElement['strand'], adjacentBlockElement['strand'])
						end
					end
									
					hashGapSet[count] = gap1_0
					count += 1
					
					hashGapSet[count] = gap1_1
					count += 1
					
					hashGapSet[count] = gap2
					count += 1
					
				#REARRANGED 2
				#previous - arrBlockElements[0] | next
				#    =               =             
				#previous - arrBlockElements[1] | next
				elsif (hashAdjacentBlocks[arrBlockElements[0]['subtype']]['prev']['block'] == hashAdjacentBlocks[arrBlockElements[1]['subtype']]['prev']['block']) && (hashAdjacentBlocks[arrBlockElements[0]['subtype']]['next']['block'] != hashAdjacentBlocks[arrBlockElements[1]['subtype']]['next']['block'])
					gap1 = Gap.new(arrBlockElements[0]['subtype'], arrBlockElements[1]['subtype'], "AdjacentInBoth")
					gap2_0 = Gap.new(arrBlockElements[0]['subtype'], arrBlockElements[1]['subtype'], "AdjacentIn#{arrBlockElements[0]['species']}Only")
					gap2_1 = Gap.new(arrBlockElements[0]['subtype'], arrBlockElements[1]['subtype'], "AdjacentIn#{arrBlockElements[1]['species']}Only")
					
					arrBlockElements.each do |blockElement|
						if (blockElement['subtype'] == arrBlockElements[0]['subtype'])
							#previous - arrBlockElement[0]
							adjacentBlockElement = hashAdjacentBlocks[blockElement['subtype']]['prev']
							gap1.input(blockElement['subtype'], blockElement['name'], adjacentBlockElement['name'], blockElement['stop'] + 1, adjacentBlockElement['start'] - 1, blockElement['strand'], adjacentBlockElement['strand'])
							
							#arrBlockElement[0] - next
							adjacentBlockElement = hashAdjacentBlocks[blockElement['subtype']]['next']
							gap2_0.input(blockElement['subtype'], blockElement['name'], adjacentBlockElement['name'], blockElement['stop'] + 1, adjacentBlockElement['start'] - 1,  blockElement['strand'], adjacentBlockElement['strand'])
							
							#Other non-adjacent genome
							nonAdjacentBlockElement = hashBlockSet[adjacentBlockElement['block']][1]
							
							#calculate start and stop of non-adjacent elements
							if (arrBlockElements[1]['chrom'] == nonAdjacentBlockElement['chrom'])
								if (arrBlockElements[1]['start'] > nonAdjacentBlockElement['stop'])
									start = nonAdjacentBlockElement['stop'] + 1
									stop = arrBlockElements[1]['start'] - 1
								else
									start = arrBlockElements[1]['stop'] + 1
									stop = nonAdjacentBlockElement['start'] - 1
								end
								
								gap2_0.input(arrBlockElements[1]['subtype'], arrBlockElements[1]['name'], nonAdjacentBlockElement['name'], start, stop, arrBlockElements[1]['strand'], nonAdjacentBlockElement['strand'])
							else
								gap2_0.input(arrBlockElements[1]['subtype'], arrBlockElements[1]['name'], nonAdjacentBlockElement['name'], 0, 0, arrBlockElements[1]['strand'], nonAdjacentBlockElement['strand'], "INF")
							end
							
							
						elsif (blockElement['subtype'] == arrBlockElements[1]['subtype'])
							#arrBlockElement[1] - next
							adjacentBlockElement = hashAdjacentBlocks[blockElement['subtype']]['prev']
							gap1.input(blockElement['subtype'], blockElement['name'], adjacentBlockElement['name'], adjacentBlockElement['stop'] + 1, blockElement['start'] - 1, blockElement['strand'], adjacentBlockElement['strand'])
						
							#prev - arrBlockElement[1]
							adjacentBlockElement = hashAdjacentBlocks[blockElement['subtype']]['next']
							gap2_1.input(blockElement['subtype'], blockElement['name'], adjacentBlockElement['name'],  blockElement['stop'] + 1, adjacentBlockElement['start'] - 1, blockElement['strand'], adjacentBlockElement['strand'])
							
							#Other non-adjacent genome
							nonAdjacentBlockElement = hashBlockSet[adjacentBlockElement['block']][0]
							
							#calculate start and stop of non-adjacent elements
							if (arrBlockElements[0]['chrom'] == nonAdjacentBlockElement['chrom'])
								if (arrBlockElements[0]['start'] > nonAdjacentBlockElement['stop'])
									start = nonAdjacentBlockElement['stop'] + 1
									stop = arrBlockElements[0]['start'] - 1
								else
									start = arrBlockElements[0]['stop'] + 1
									stop = nonAdjacentBlockElement['start'] - 1
								end
								
								gap2_1.input(arrBlockElements[0]['subtype'], arrBlockElements[0]['name'], nonAdjacentBlockElement['name'], start, stop, arrBlockElements[0]['strand'], nonAdjacentBlockElement['strand'])
							else
								gap2_1.input(arrBlockElements[0]['subtype'], arrBlockElements[0]['name'], nonAdjacentBlockElement['name'], 0, 0, arrBlockElements[0]['strand'], nonAdjacentBlockElement['strand'], "INF")
							end
						end
					end
										
					hashGapSet[count] = gap1
					count += 1
					
					hashGapSet[count] = gap2_0
					count += 1
					
					hashGapSet[count] = gap2_1
					count += 1
				
				#REARRANGED 3
				#previous | arrBlockElements[0] - next
				#                    =             =
				#next     | arrBlockElements[1] - previous
				elsif (hashAdjacentBlocks[arrBlockElements[0]['subtype']]['prev']['block'] != hashAdjacentBlocks[arrBlockElements[1]['subtype']]['next']['block']) && (hashAdjacentBlocks[arrBlockElements[0]['subtype']]['next']['block'] == hashAdjacentBlocks[arrBlockElements[1]['subtype']]['prev']['block'])
					gap1_0 = Gap.new(arrBlockElements[0]['subtype'], arrBlockElements[1]['subtype'], "AdjacentIn#{arrBlockElements[0]['species']}Only")
					gap1_1 = Gap.new(arrBlockElements[0]['subtype'], arrBlockElements[1]['subtype'], "AdjacentIn#{arrBlockElements[1]['species']}Only")
					gap2 = Gap.new(arrBlockElements[0]['subtype'], arrBlockElements[1]['subtype'], "AdjacentInBoth")
					
					arrBlockElements.each do |blockElement|
						if (blockElement['subtype'] == arrBlockElements[0]['subtype'])
							#previous - arrBlockElement[0]
							adjacentBlockElement = hashAdjacentBlocks[blockElement['subtype']]['prev']
							gap1_0.input(blockElement['subtype'], blockElement['name'], adjacentBlockElement['name'], adjacentBlockElement['stop'] + 1, blockElement['start'] - 1, blockElement['strand'], adjacentBlockElement['strand'])
							
							#Other non-adjacent genome
							nonAdjacentBlockElement = hashBlockSet[adjacentBlockElement['block']][1]
							
							#calculate start and stop of non-adjacent elements
							if (arrBlockElements[1]['chrom'] == nonAdjacentBlockElement['chrom'])
								if (arrBlockElements[1]['start'] > nonAdjacentBlockElement['stop'])
									start = nonAdjacentBlockElement['stop'] + 1
									stop = arrBlockElements[1]['start'] - 1
								else
									start = arrBlockElements[1]['stop'] + 1
									stop = nonAdjacentBlockElement['start'] - 1
								end
								
								gap1_0.input(arrBlockElements[1]['subtype'], arrBlockElements[1]['name'], nonAdjacentBlockElement['name'], start, stop, arrBlockElements[1]['strand'], nonAdjacentBlockElement['strand'])
							else
								gap1_0.input(arrBlockElements[1]['subtype'], arrBlockElements[1]['name'], nonAdjacentBlockElement['name'], 0, 0, arrBlockElements[1]['strand'], nonAdjacentBlockElement['strand'], "INF")
							end
							
							#arrBlockElement[0] - next
							adjacentBlockElement = hashAdjacentBlocks[blockElement['subtype']]['next']
							gap2.input(blockElement['subtype'], blockElement['name'], adjacentBlockElement['name'], blockElement['stop'] + 1, adjacentBlockElement['start'] - 1, blockElement['strand'], adjacentBlockElement['strand'])
						elsif (blockElement['subtype'] == arrBlockElements[1]['subtype'])
							#next - arrBlockElement[1]
							adjacentBlockElement = hashAdjacentBlocks[blockElement['subtype']]['next']
							gap1_1.input(blockElement['subtype'], blockElement['name'], adjacentBlockElement['name'],  blockElement['stop'] + 1, adjacentBlockElement['start'] - 1, blockElement['strand'], adjacentBlockElement['strand'])
							
							#Other non-adjacent genome
							nonAdjacentBlockElement = hashBlockSet[adjacentBlockElement['block']][0]
							
							#calculate start and stop of non-adjacent elements
							if (arrBlockElements[0]['chrom'] == nonAdjacentBlockElement['chrom'])
								if (arrBlockElements[0]['start'] > nonAdjacentBlockElement['stop'])
									start = nonAdjacentBlockElement['stop'] + 1
									stop = arrBlockElements[0]['start'] - 1
								else
									start = arrBlockElements[0]['stop'] + 1
									stop = nonAdjacentBlockElement['start'] - 1
								end
								
								gap1_1.input(arrBlockElements[0]['subtype'], arrBlockElements[0]['name'], nonAdjacentBlockElement['name'], start, stop, arrBlockElements[0]['strand'], nonAdjacentBlockElement['strand'])
							else
								gap1_1.input(arrBlockElements[0]['subtype'], arrBlockElements[0]['name'], nonAdjacentBlockElement['name'], 0, 0, arrBlockElements[0]['strand'], nonAdjacentBlockElement['strand'], "INF")
							end
							
							#arrBlockElement[1] - prev
							adjacentBlockElement = hashAdjacentBlocks[blockElement['subtype']]['prev']
							gap2.input(blockElement['subtype'], blockElement['name'], adjacentBlockElement['name'], adjacentBlockElement['stop'] + 1, blockElement['start'] - 1, blockElement['strand'], adjacentBlockElement['strand'])
						end
					end
										
					hashGapSet[count] = gap1_0
					count += 1
					
					hashGapSet[count] = gap1_1
					count += 1
					
					hashGapSet[count] = gap2
					count += 1
				
				#REARRANGED 4
				#previous - arrBlockElements[0] | next
				#    =               =             
				#next     - arrBlockElements[1] | previous
				elsif (hashAdjacentBlocks[arrBlockElements[0]['subtype']]['prev']['block'] == hashAdjacentBlocks[arrBlockElements[1]['subtype']]['next']['block']) && (hashAdjacentBlocks[arrBlockElements[0]['subtype']]['next']['block'] != hashAdjacentBlocks[arrBlockElements[1]['subtype']]['prev']['block'])
					gap1 = Gap.new(arrBlockElements[0]['subtype'], arrBlockElements[1]['subtype'], "AdjacentInBoth")
					gap2_0 = Gap.new(arrBlockElements[0]['subtype'], arrBlockElements[1]['subtype'], "AdjacentIn#{arrBlockElements[0]['species']}Only")
					gap2_1 = Gap.new(arrBlockElements[0]['subtype'], arrBlockElements[1]['subtype'], "AdjacentIn#{arrBlockElements[1]['species']}Only")
					
					arrBlockElements.each do |blockElement|
						if (blockElement['subtype'] == arrBlockElements[0]['subtype'])
							#previous - arrBlockElement[0]
							adjacentBlockElement = hashAdjacentBlocks[blockElement['subtype']]['prev']
							gap1.input(blockElement['subtype'], blockElement['name'], adjacentBlockElement['name'], blockElement['stop'] + 1, adjacentBlockElement['start'] - 1, blockElement['strand'], adjacentBlockElement['strand'])
							
							#arrBlockElement[0] - next
							adjacentBlockElement = hashAdjacentBlocks[blockElement['subtype']]['next']
							gap2_0.input(blockElement['subtype'], blockElement['name'], adjacentBlockElement['name'],  blockElement['stop'] + 1, adjacentBlockElement['start'] - 1, blockElement['strand'], adjacentBlockElement['strand'])
							
							#Other non-adjacent genome
							nonAdjacentBlockElement = hashBlockSet[adjacentBlockElement['block']][1]
							
							#calculate start and stop of non-adjacent elements
							if (arrBlockElements[1]['chrom'] == nonAdjacentBlockElement['chrom'])
								if (arrBlockElements[1]['start'] > nonAdjacentBlockElement['stop'])
									start = nonAdjacentBlockElement['stop'] + 1
									stop = arrBlockElements[1]['start'] - 1
								else
									start = arrBlockElements[1]['stop'] + 1
									stop = nonAdjacentBlockElement['start'] - 1
								end
								
								gap2_0.input(arrBlockElements[1]['subtype'], arrBlockElements[1]['name'], nonAdjacentBlockElement['name'], start, stop, arrBlockElements[1]['strand'], nonAdjacentBlockElement['strand'])
							else
								gap2_0.input(arrBlockElements[1]['subtype'], arrBlockElements[1]['name'], nonAdjacentBlockElement['name'], 0, 0, arrBlockElements[1]['strand'], nonAdjacentBlockElement['strand'], "INF")
							end
							
							
						elsif (blockElement['subtype'] == arrBlockElements[1]['subtype'])
							#next - arrBlockElement[1]
							adjacentBlockElement = hashAdjacentBlocks[blockElement['subtype']]['next']
							gap1.input(blockElement['subtype'], blockElement['name'], adjacentBlockElement['name'], adjacentBlockElement['stop'] + 1, blockElement['start'] - 1, blockElement['strand'], adjacentBlockElement['strand'])
						
							#arrBlockElement[1] - prev
							adjacentBlockElement = hashAdjacentBlocks[blockElement['subtype']]['prev']
							gap2_1.input(blockElement['subtype'], blockElement['name'], adjacentBlockElement['name'], adjacentBlockElement['stop'] + 1, blockElement['start'] - 1, blockElement['strand'], adjacentBlockElement['strand'])
							
							#Other non-adjacent genome
							nonAdjacentBlockElement = hashBlockSet[adjacentBlockElement['block']][0]
							
							#calculate start and stop of non-adjacent elements
							if (arrBlockElements[0]['chrom'] == nonAdjacentBlockElement['chrom'])
								if (arrBlockElements[0]['start'] > nonAdjacentBlockElement['stop'])
									start = nonAdjacentBlockElement['stop'] + 1
									stop = arrBlockElements[0]['start'] - 1
								else
									start = arrBlockElements[0]['stop'] + 1
									stop = nonAdjacentBlockElement['start'] - 1
								end
								
								gap2_1.input(arrBlockElements[0]['subtype'], arrBlockElements[0]['name'], nonAdjacentBlockElement['name'], start, stop, arrBlockElements[0]['strand'], nonAdjacentBlockElement['strand'])
							else
								gap2_1.input(arrBlockElements[0]['subtype'], arrBlockElements[0]['name'], nonAdjacentBlockElement['name'], 0, 0, arrBlockElements[0]['strand'], nonAdjacentBlockElement['strand'], "INF")
							end
						end
					end
										
					hashGapSet[count] = gap1
					count += 1
					
					hashGapSet[count] = gap2_0
					count += 1
					
					hashGapSet[count] = gap2_1
					count += 1	
				end
					
			#-----------------------------------------------------------------
			#Next or previous nil in both genomes
			#-----------------------------------------------------------------
			
			#No previous and nexts match - beginning of chromosome
			#prev/nil - arrBlockElements[0] - next
			#                   =               =
			#prev/nil - arrBlockElements[1] - next
			elsif (hashAdjacentBlocks[arrBlockElements[0]['subtype']]['prev'].nil? || hashAdjacentBlocks[arrBlockElements[1]['subtype']]['prev'].nil?) && (!hashAdjacentBlocks[arrBlockElements[0]['subtype']]['next'].nil? && !hashAdjacentBlocks[arrBlockElements[1]['subtype']]['next'].nil?) && (hashAdjacentBlocks[arrBlockElements[0]['subtype']]['next']['block'] == hashAdjacentBlocks[arrBlockElements[1]['subtype']]['next']['block'])
				gap1 = nil
				gap2 = Gap.new(arrBlockElements[0]['subtype'], arrBlockElements[1]['subtype'], "AdjacentInBoth")
				
				arrBlockElements.each do |blockElement|
					#arrBlockElement - next
					adjacentBlockElement = hashAdjacentBlocks[blockElement['subtype']]['next']
					gap2.input(blockElement['subtype'], blockElement['name'], adjacentBlockElement['name'], blockElement['stop'] + 1, adjacentBlockElement['start'] - 1, blockElement['strand'], adjacentBlockElement['strand'])
				
					if (!hashAdjacentBlocks[arrBlockElements[0]['subtype']]['prev'].nil?) && (blockElement['subtype'] == arrBlockElements[0]['subtype'])
						gap1 = Gap.new(arrBlockElements[0]['subtype'], arrBlockElements[1]['subtype'], "AdjacentIn#{arrBlockElements[0]['species']}Only")
						adjacentBlockElement = hashAdjacentBlocks[blockElement['subtype']]['prev']
						gap1.input(blockElement['subtype'], blockElement['name'], adjacentBlockElement['name'], adjacentBlockElement['stop'] + 1, blockElement['start'] - 1, blockElement['strand'], adjacentBlockElement['strand'])

						#Other non-adjacent genome
						nonAdjacentBlockElement = hashBlockSet[adjacentBlockElement['block']][1]
						
						#calculate start and stop of non-adjacent elements
						if (arrBlockElements[1]['chrom'] == nonAdjacentBlockElement['chrom'])
							if (arrBlockElements[1]['start'] > nonAdjacentBlockElement['stop'])
								start = nonAdjacentBlockElement['stop'] + 1
								stop = arrBlockElements[1]['start'] - 1
							else
								start = arrBlockElements[1]['stop'] + 1
								stop = nonAdjacentBlockElement['start'] - 1
							end
							
							gap1.input(arrBlockElements[1]['subtype'], arrBlockElements[1]['name'], nonAdjacentBlockElement['name'], start, stop, arrBlockElements[1]['strand'], nonAdjacentBlockElement['strand'])
						else
							gap1.input(arrBlockElements[1]['subtype'], arrBlockElements[1]['name'], nonAdjacentBlockElement['name'], 0, 0, arrBlockElements[1]['strand'], nonAdjacentBlockElement['strand'], "INF")
						end
							
					elsif (!hashAdjacentBlocks[arrBlockElements[1]['subtype']]['prev'].nil?) && (blockElement['subtype'] == arrBlockElements[1]['subtype'])
						gap1 = Gap.new(arrBlockElements[0]['subtype'], arrBlockElements[1]['subtype'], "AdjacentIn#{arrBlockElements[1]['species']}Only")
						adjacentBlockElement = hashAdjacentBlocks[blockElement['subtype']]['prev']
						gap1.input(blockElement['subtype'], blockElement['name'], adjacentBlockElement['name'], adjacentBlockElement['stop'] + 1, blockElement['start'] - 1, blockElement['strand'], adjacentBlockElement['strand'])

						#Other non-adjacent genome
						nonAdjacentBlockElement = hashBlockSet[adjacentBlockElement['block']][0]
						
						#calculate start and stop of non-adjacent elements
						if (arrBlockElements[0]['chrom'] == nonAdjacentBlockElement['chrom'])
							if (arrBlockElements[0]['start'] > nonAdjacentBlockElement['stop'])
								start = nonAdjacentBlockElement['stop'] + 1
								stop = arrBlockElements[0]['start'] - 1
							else
								start = arrBlockElements[0]['stop'] + 1
								stop = nonAdjacentBlockElement['start'] - 1
							end
							
							gap1.input(arrBlockElements[0]['subtype'], arrBlockElements[0]['name'], nonAdjacentBlockElement['name'], start, stop, arrBlockElements[0]['strand'], nonAdjacentBlockElement['strand'])
						else
							gap1.input(arrBlockElements[0]['subtype'], arrBlockElements[0]['name'], nonAdjacentBlockElement['name'], 0, 0, arrBlockElements[0]['strand'], nonAdjacentBlockElement['strand'], "INF")
						end
					end
				end
				
				unless (gap1.nil?)
					hashGapSet[count] = gap1
					count += 1
				end
				
				hashGapSet[count] = gap2
				count += 1
				
			#No next and previous matches - end of chromosome
			#prev - arrBlockElements[0] - next/nil
			#  =              =           
			#prev - arrBlockElements[1] - next/nil
			elsif (!hashAdjacentBlocks[arrBlockElements[0]['subtype']]['prev'].nil? && !hashAdjacentBlocks[arrBlockElements[1]['subtype']]['prev'].nil?) && (hashAdjacentBlocks[arrBlockElements[0]['subtype']]['next'].nil? || hashAdjacentBlocks[arrBlockElements[1]['subtype']]['next'].nil?) && (hashAdjacentBlocks[arrBlockElements[0]['subtype']]['prev']['block'] == hashAdjacentBlocks[arrBlockElements[1]['subtype']]['prev']['block'])
				gap1 = Gap.new(arrBlockElements[0]['subtype'], arrBlockElements[1]['subtype'], "AdjacentInBoth")
				gap2 = nil
				
				arrBlockElements.each do |blockElement|
					#arrBlockElement - prev
					adjacentBlockElement = hashAdjacentBlocks[blockElement['subtype']]['prev']
					gap1.input(blockElement['subtype'], blockElement['name'], adjacentBlockElement['name'], blockElement['stop'] + 1, adjacentBlockElement['start'] - 1, blockElement['strand'], adjacentBlockElement['strand'])
				
					if (!hashAdjacentBlocks[arrBlockElements[0]['subtype']]['next'].nil?) && (blockElement['subtype'] == arrBlockElements[0]['subtype'])
						gap2 = Gap.new(arrBlockElements[0]['subtype'], arrBlockElements[1]['subtype'], "AdjacentIn#{arrBlockElements[0]['species']}Only")
						adjacentBlockElement = hashAdjacentBlocks[blockElement['subtype']]['next']
						gap2.input(blockElement['subtype'], blockElement['name'], adjacentBlockElement['name'],  blockElement['stop'] + 1, adjacentBlockElement['start'] - 1, blockElement['strand'], adjacentBlockElement['strand'])

						#Other non-adjacent genome
						nonAdjacentBlockElement = hashBlockSet[adjacentBlockElement['block']][1]
						
						#calculate start and stop of non-adjacent elements
						if (arrBlockElements[1]['chrom'] == nonAdjacentBlockElement['chrom'])
							if (arrBlockElements[1]['start'] > nonAdjacentBlockElement['stop'])
								start = nonAdjacentBlockElement['stop'] + 1
								stop = arrBlockElements[1]['start'] - 1
							else
								start = arrBlockElements[1]['stop'] + 1
								stop = nonAdjacentBlockElement['start'] - 1
							end
							
							gap2.input(arrBlockElements[1]['subtype'], arrBlockElements[1]['name'], nonAdjacentBlockElement['name'], start, stop, arrBlockElements[1]['strand'], nonAdjacentBlockElement['strand'])
						else
							gap2.input(arrBlockElements[1]['subtype'], arrBlockElements[1]['name'], nonAdjacentBlockElement['name'], 0, 0, arrBlockElements[1]['strand'], nonAdjacentBlockElement['strand'], "INF")
						end
							
					elsif (!hashAdjacentBlocks[arrBlockElements[1]['subtype']]['next'].nil?) && (blockElement['subtype'] == arrBlockElements[1]['subtype'])
						gap2 = Gap.new(arrBlockElements[0]['subtype'], arrBlockElements[1]['subtype'], "AdjacentIn#{arrBlockElements[1]['species']}Only")
						adjacentBlockElement = hashAdjacentBlocks[blockElement['subtype']]['next']
						gap2.input(blockElement['subtype'], blockElement['name'], adjacentBlockElement['name'], blockElement['stop'] + 1, adjacentBlockElement['start'] - 1, blockElement['strand'], adjacentBlockElement['strand'])

						#Other non-adjacent genome
						nonAdjacentBlockElement = hashBlockSet[adjacentBlockElement['block']][0]
						
						#calculate start and stop of non-adjacent elements
						if (arrBlockElements[0]['chrom'] == nonAdjacentBlockElement['chrom'])
							if (arrBlockElements[0]['start'] > nonAdjacentBlockElement['stop'])
								start = nonAdjacentBlockElement['stop'] + 1
								stop = arrBlockElements[0]['start'] - 1
							else
								start = arrBlockElements[0]['stop'] + 1
								stop = nonAdjacentBlockElement['start'] - 1
							end
							
							gap2.input(arrBlockElements[0]['subtype'], arrBlockElements[0]['name'], nonAdjacentBlockElement['name'], start, stop, arrBlockElements[0]['strand'], nonAdjacentBlockElement['strand'])
						else
							gap2.input(arrBlockElements[0]['subtype'], arrBlockElements[0]['name'], nonAdjacentBlockElement['name'], 0, 0, arrBlockElements[0]['strand'], nonAdjacentBlockElement['strand'], "INF")
						end
					end
				end
				
				hashGapSet[count] = gap1
				count += 1

				unless (gap2.nil?)
					hashGapSet[count] = gap2
					count += 1
				end
			
			#prev/nil - arrBlockElements[0] - next
			#                    =             =
			#next/nil - arrBlockElements[1] - prev
			elsif (hashAdjacentBlocks[arrBlockElements[0]['subtype']]['prev'].nil? || hashAdjacentBlocks[arrBlockElements[1]['subtype']]['next'].nil?) && (!hashAdjacentBlocks[arrBlockElements[0]['subtype']]['next'].nil? && !hashAdjacentBlocks[arrBlockElements[1]['subtype']]['prev'].nil?) && (hashAdjacentBlocks[arrBlockElements[0]['subtype']]['next']['block'] == hashAdjacentBlocks[arrBlockElements[1]['subtype']]['prev']['block'])
				gap1 = nil
				gap2 = Gap.new(arrBlockElements[0]['subtype'], arrBlockElements[1]['subtype'], "AdjacentInBoth")
				
				arrBlockElements.each do |blockElement|
					if (blockElement['subtype'] == arrBlockElements[0]['subtype'])
						#arrBlockElement[0] - next
						adjacentBlockElement = hashAdjacentBlocks[blockElement['subtype']]['next']
						gap2.input(blockElement['subtype'], blockElement['name'], adjacentBlockElement['name'], blockElement['stop'] + 1, adjacentBlockElement['start'] - 1, blockElement['strand'], adjacentBlockElement['strand'])
					elsif (blockElement['subtype'] == arrBlockElements[1]['subtype'])
						#arrBlockElement[1] - prev
						adjacentBlockElement = hashAdjacentBlocks[blockElement['subtype']]['prev']
						gap2.input(blockElement['subtype'], blockElement['name'], adjacentBlockElement['name'], adjacentBlockElement['stop'] + 1, blockElement['start'] - 1, blockElement['strand'], adjacentBlockElement['strand'])
					end
				
					if (!hashAdjacentBlocks[arrBlockElements[0]['subtype']]['prev'].nil?) && (blockElement['subtype'] == arrBlockElements[0]['subtype'])
						gap1 = Gap.new(arrBlockElements[0]['subtype'], arrBlockElements[1]['subtype'], "AdjacentIn#{arrBlockElements[0]['species']}Only")
						adjacentBlockElement = hashAdjacentBlocks[blockElement['subtype']]['prev']
						gap1.input(blockElement['subtype'], blockElement['name'], adjacentBlockElement['name'], adjacentBlockElement['stop'] + 1, blockElement['start'] - 1, blockElement['strand'], adjacentBlockElement['strand'])

						#Other non-adjacent genome
						nonAdjacentBlockElement = hashBlockSet[adjacentBlockElement['block']][1]
						
						#calculate start and stop of non-adjacent elements
						if (arrBlockElements[1]['chrom'] == nonAdjacentBlockElement['chrom'])
							if (arrBlockElements[1]['start'] > nonAdjacentBlockElement['stop'])
								start = nonAdjacentBlockElement['stop'] + 1
								stop = arrBlockElements[1]['start'] - 1
							else
								start = arrBlockElements[1]['stop'] + 1
								stop = nonAdjacentBlockElement['start'] - 1
							end
							
							gap1.input(arrBlockElements[1]['subtype'], arrBlockElements[1]['name'], nonAdjacentBlockElement['name'], start, stop, arrBlockElements[1]['strand'], nonAdjacentBlockElement['strand'])
						else
							gap1.input(arrBlockElements[1]['subtype'], arrBlockElements[1]['name'], nonAdjacentBlockElement['name'], 0, 0, arrBlockElements[1]['strand'], nonAdjacentBlockElement['strand'], "INF")
						end
							
					elsif (!hashAdjacentBlocks[arrBlockElements[1]['subtype']]['next'].nil?) && (blockElement['subtype'] == arrBlockElements[1]['subtype'])
						gap1 = Gap.new(arrBlockElements[0]['subtype'], arrBlockElements[1]['subtype'], "AdjacentIn#{arrBlockElements[1]['species']}Only")
						adjacentBlockElement = hashAdjacentBlocks[blockElement['subtype']]['next']
						gap1.input(blockElement['subtype'], blockElement['name'], adjacentBlockElement['name'], blockElement['stop'] + 1, adjacentBlockElement['start'] - 1,  blockElement['strand'], adjacentBlockElement['strand'])

						#Other non-adjacent genome
						nonAdjacentBlockElement = hashBlockSet[adjacentBlockElement['block']][0]
						
						#calculate start and stop of non-adjacent elements
						if (arrBlockElements[0]['chrom'] == nonAdjacentBlockElement['chrom'])
							if (arrBlockElements[0]['start'] > nonAdjacentBlockElement['stop'])
								start = nonAdjacentBlockElement['stop'] + 1
								stop = arrBlockElements[0]['start'] - 1
							else
								start = arrBlockElements[0]['stop'] + 1
								stop = nonAdjacentBlockElement['start'] - 1
							end
							
							gap1.input(arrBlockElements[0]['subtype'], arrBlockElements[0]['name'], nonAdjacentBlockElement['name'], start, stop, arrBlockElements[0]['strand'], nonAdjacentBlockElement['strand'])
						else
							gap1.input(arrBlockElements[0]['subtype'], arrBlockElements[0]['name'], nonAdjacentBlockElement['name'], 0, 0, arrBlockElements[0]['strand'], nonAdjacentBlockElement['strand'], "INF")
						end
					end
				end
				
				unless (gap1.nil?)
					hashGapSet[count] = gap1
					count += 1
				end
				
				hashGapSet[count] = gap2
				count += 1
			
			#prev - arrBlockElements[0] - next/nil
			#  =             =
			#next - arrBlockElements[1] - prev/nil
			elsif (!hashAdjacentBlocks[arrBlockElements[0]['subtype']]['prev'].nil? && !hashAdjacentBlocks[arrBlockElements[1]['subtype']]['next'].nil?) && (hashAdjacentBlocks[arrBlockElements[0]['subtype']]['next'].nil? || hashAdjacentBlocks[arrBlockElements[1]['subtype']]['prev'].nil?) && (hashAdjacentBlocks[arrBlockElements[0]['subtype']]['prev']['block'] == hashAdjacentBlocks[arrBlockElements[1]['subtype']]['next']['block'])
				gap1 = Gap.new(arrBlockElements[0]['subtype'], arrBlockElements[1]['subtype'], "AdjacentInBoth")
				gap2 = nil
				
				arrBlockElements.each do |blockElement|
					if (blockElement['subtype'] == arrBlockElements[0]['subtype'])
						#arrBlockElement[0] - next
						adjacentBlockElement = hashAdjacentBlocks[blockElement['subtype']]['prev']
						gap1.input(blockElement['subtype'], blockElement['name'], adjacentBlockElement['name'], blockElement['stop'] + 1, adjacentBlockElement['start'] - 1, blockElement['strand'], adjacentBlockElement['strand'])
					elsif (blockElement['subtype'] == arrBlockElements[1]['subtype'])
						#arrBlockElement[1] - prev
						adjacentBlockElement = hashAdjacentBlocks[blockElement['subtype']]['next']
						gap1.input(blockElement['subtype'], blockElement['name'], adjacentBlockElement['name'], adjacentBlockElement['stop'] + 1, blockElement['start'] - 1, blockElement['strand'], adjacentBlockElement['strand'])
					end
				
					
					if (!hashAdjacentBlocks[arrBlockElements[0]['subtype']]['next'].nil?) && (blockElement['subtype'] == arrBlockElements[0]['subtype'])
						gap2 = Gap.new(arrBlockElements[0]['subtype'], arrBlockElements[1]['subtype'], "AdjacentIn#{arrBlockElements[0]['species']}Only")
						adjacentBlockElement = hashAdjacentBlocks[blockElement['subtype']]['next']
						gap2.input(blockElement['subtype'], blockElement['name'], adjacentBlockElement['name'], blockElement['stop'] + 1, adjacentBlockElement['start'] - 1,  blockElement['strand'], adjacentBlockElement['strand'])

						#Other non-adjacent genome
						nonAdjacentBlockElement = hashBlockSet[adjacentBlockElement['block']][1]
						
						#calculate start and stop of non-adjacent elements
						if (arrBlockElements[1]['chrom'] == nonAdjacentBlockElement['chrom'])
							if (arrBlockElements[1]['start'] > nonAdjacentBlockElement['stop'])
								start = nonAdjacentBlockElement['stop'] + 1
								stop = arrBlockElements[1]['start'] - 1
							else
								start = arrBlockElements[1]['stop'] + 1
								stop = nonAdjacentBlockElement['start'] - 1
							end
							
							gap2.input(arrBlockElements[1]['subtype'], arrBlockElements[1]['name'], nonAdjacentBlockElement['name'], start, stop, arrBlockElements[1]['strand'], nonAdjacentBlockElement['strand'])
						else
							gap2.input(arrBlockElements[1]['subtype'], arrBlockElements[1]['name'], nonAdjacentBlockElement['name'], 0, 0, arrBlockElements[1]['strand'], nonAdjacentBlockElement['strand'], "INF")
						end
							
					elsif (!hashAdjacentBlocks[arrBlockElements[1]['subtype']]['prev'].nil?) && (blockElement['subtype'] == arrBlockElements[1]['subtype'])
						gap2 = Gap.new(arrBlockElements[0]['subtype'], arrBlockElements[1]['subtype'], "AdjacentIn#{arrBlockElements[1]['species']}Only")
						adjacentBlockElement = hashAdjacentBlocks[blockElement['subtype']]['prev']
						gap2.input(blockElement['subtype'], blockElement['name'], adjacentBlockElement['name'], adjacentBlockElement['stop'] - 1, blockElement['start'] - 1, blockElement['strand'], adjacentBlockElement['strand'])

						#Other non-adjacent genome
						nonAdjacentBlockElement = hashBlockSet[adjacentBlockElement['block']][0]
						
						#calculate start and stop of non-adjacent elements
						if (arrBlockElements[0]['chrom'] == nonAdjacentBlockElement['chrom'])
							if (arrBlockElements[0]['start'] > nonAdjacentBlockElement['stop'])
								start = nonAdjacentBlockElement['stop'] + 1
								stop = arrBlockElements[0]['start'] - 1
							else
								start = arrBlockElements[0]['stop'] + 1
								stop = nonAdjacentBlockElement['start'] - 1
							end
							
							gap2.input(arrBlockElements[0]['subtype'], arrBlockElements[0]['name'], nonAdjacentBlockElement['name'], start, stop, arrBlockElements[0]['strand'], nonAdjacentBlockElement['strand'])
						else
							gap2.input(arrBlockElements[0]['subtype'], arrBlockElements[0]['name'], nonAdjacentBlockElement['name'], 0, 0, arrBlockElements[0]['strand'], nonAdjacentBlockElement['strand'], "INF")
						end
					end
				end
				
				hashGapSet[count] = gap1
				count += 1

				unless (gap2.nil?)
					hashGapSet[count] = gap2
					count += 1
				end
			end
		end
	end
end

count = 1
sortedHashGapSet = hashGapSet.sort
sortedHashGapSet.each do |gapNumber, gap|
	unless (gap.nil?)
		targetCounter = 0
		sortedHashGapSet.each do |targetGapNumber, targetGap|
			unless (targetGap.nil?)
				unless (gapNumber == targetGapNumber)
					
					#This means that the same blocks are adjacent in both but in a different order (2 block inversion)
					if ((gap.block1(gap.genome1) == targetGap.block1(gap.genome1)) && (gap.block2(gap.genome1) == targetGap.block2(gap.genome1))) || ((gap.block1(gap.genome1) == targetGap.block2(gap.genome1)) && (gap.block2(gap.genome1) == targetGap.block1(gap.genome1)))
						sortedHashGapSet[targetCounter][1] = nil
					end
				end
			end
			targetCounter += 1
		end
	
		gap.output(count)
	
		count += 1
	end
end
