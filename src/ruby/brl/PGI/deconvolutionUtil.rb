#!/usr/bin/env ruby
$VERBOSE = 1

require 'brl/util/textFileUtil'
require 'brl/util/util'
require 'brl/pgi/PGIIndex'

module BRL; module PGI

class DeconvolutionUtil
	
	def initialize(inputFile, numberOfPools)
		
		if (FileTest.exists?(inputFile))
			#Open file for reading
			reader = BRL::Util::TextReader.new(inputFile)
		else
			raise "\nERROR: File #{inputFile} does not exist.\n"
		end
		
		
		@indices = BRL::PGI::PGIMultiHit.new(reader,numberOfPools)
		@numberOfPools = numberOfPools
		#Hash for multiple mappings
		@hashMappings = Hash.new
	end
	
	def rankPools()
		hashPools = Hash.new
		
		@indices.each do
			|index|
			
			indexOrder = index.numPoolsWithAtLeast1Hit.to_i
			i = 0
			
			index.numHitsPerPool.each do
				|hits|
				
				if (hits.to_i > 0)
					pool = index.poolIDs[i]
					
					if (hashPools.has_key?(pool))
						hashData = hashPools[pool]
						
						if (indexOrder == 4)
							hashData["4"] = hashData["4"] + 1
						elsif (indexOrder == 3)
							hashData["3"] = hashData["3"] + 1
						elsif (indexOrder == 2)
							hashData["2"] = hashData["2"] + 1
						end
						
						hashPools[pool] = hashData
					else
						hashData = Hash.new
						
						hashData["4"] = 0
						hashData["3"] = 0
						hashData["2"] = 0
						
						if (indexOrder == 4)
							hashData["4"] = 1
						elsif (indexOrder == 3)
							hashData["3"] = 1
						elsif (indexOrder == 2)
							hashData["2"] = 1
						end
						
						hashPools[pool] = hashData
					end
				end
				
				i += 1
			end
		end
		
		hashPools.each do
			|pool, hashData|
			
			puts "#{pool}\t#{hashData['4']}\t#{hashData['3']}\t#{hashData['2']}"
		end
	end
	
	def substitutePools(inputFile, sourcePool, targetPool)
		if (FileTest.exists?(inputFile))
			#Open file for reading
			reader = BRL::Util::TextReader.new(inputFile)
		else
			raise "\nERROR: File #{inputFile} does not exist.\n"
		end
		
		hashClusters = Hash.new()
		
		reader.each do
			| line |
			
			line.strip!
			
			if (line =~ /^P/)
				arrSplit = line.split(/\s+/)
				
				hashData = Hash.new()
				
				pool = arrSplit[0]
				pool.downcase!
				
				hashData["numberOfReads"] = arrSplit[2]
				hashData["size"] = arrSplit[3]
				hashData["chrom"] = arrSplit[4]
				hashData["start"] = arrSplit[5].to_i
				hashData["stop"] = arrSplit[6].to_i
				hashData["range"] = (hashData["start"]..hashData["stop"])
				hashData["record"] = line
				
				if(hashClusters.has_key?(pool))
					arrClusters = hashClusters[pool]
					arrClusters.push(hashData)
					hashClusters[pool] = arrClusters
				else
					arrClusters = Array.new
					arrClusters.push(hashData)
					hashClusters[pool] = arrClusters
				end
			end
		end
		
		sourcePoolClusters = hashClusters[sourcePool]
		mergeRadius = 200000
		
		@indices.each do
			|index|
			
			if (index.poolIDs.include?(targetPool)) && (!index.poolIDs.include?(sourcePool))
				
				sourcePoolClusters.each do
					|cluster|
					
					indexChrom = index.idxChr.gsub(".fa","")
					
					if (cluster["chrom"] == indexChrom)
						clusterRange = ((cluster["start"] - mergeRadius)..(cluster["stop"] + mergeRadius))
						indexRange = ((index.idxStart.to_i - mergeRadius)..(index.idxEnd.to_i + mergeRadius))
						
						if (clusterRange.rangesOverlap?(indexRange))
							puts index.to_s
							puts cluster["record"]
						end
					end
				end
				
			end			
		end
	end
	
	
	def compareToClusters(inputFile)
		
		if (FileTest.exists?(inputFile))
			#Open file for reading
			reader = BRL::Util::TextReader.new(inputFile)
		else
			raise "\nERROR: File #{inputFile} does not exist.\n"
		end
		
		hashClusters = Hash.new()
		
		reader.each do
			| line |
			
			line.strip!
			
			if (line =~ /^P/)
				arrSplit = line.split(/\s+/)
				
				hashData = Hash.new()
				
				pool = arrSplit[0]
				pool.downcase!
				
				hashData["numberOfReads"] = arrSplit[2]
				hashData["size"] = arrSplit[3]
				hashData["chrom"] = arrSplit[3]
				hashData["start"] = arrSplit[4].to_i
				hashData["stop"] = arrSplit[5].to_i
				hashData["range"] = (hashData["start"]..hashData["stop"])
				hashData["record"] = line
				
				if(hashClusters.has_key?(pool))
					arrClusters = hashClusters[pool]
					arrClusters.push(hashData)
					hashClusters[pool] = arrClusters
				else
					arrClusters = Array.new
					arrClusters.push(hashData)
					hashClusters[pool] = arrClusters
				end
			end
		end
		
		@indices.each do
			|index|
			
			i = 0
			
			index.numHitsPerPool.each do
				|hits|
				
				if (hits.to_i > 0)
					pool = index.poolIDs[i]
					
					if (hashClusters.has_key?(pool))
						arrClusters = hashClusters[pool]
						
						arrClusters.each do
							|cluster|
							
							indexRange = (index.idxStart..index.idxEnd)
							
							if (cluster["range"].rangesOverlap?(indexRange))
								puts index
								puts 
							end
						end
					end
				end
				
				i += 1
			end
		end
		
		
	end
	
	def findConfirmations(inputFile, outputFile)
		if (FileTest.exists?(inputFile))
			#Open file for reading
			reader = BRL::Util::TextReader.new(inputFile)
		else
			raise "\nERROR: File #{inputFile} does not exist.\n"
		end
		
		reader.each do
			| line |
			
			line.strip!
			
			arrSplit = line.split(/\s+/)
			
			bac = arrSplit[0]
			confirm = arrSplit[2]
			chrom = arrSplit[3]
			start = arrSplit[4]
			stop = arrSplit[5]
			
			@indices.each do
				|index|
				
				if (index.bacID == bac) && (index.idxChr == chrom) && (index.idxStart == start) && (index.idxEnd == stop)
					index.isConfirmViaDirect = confirm
				end
			end
		end
		
		writer = BRL::Util::TextWriter.new(outputFile,"w",false)
		
		@indices.each do 
			| tempIndex |
			
			writer.write(tempIndex.to_s)
		end
	end
	
	def findInterchromosomalBreakPoints(minNumberOfPoolsWithHits)
	
		#Hash for indices
		hashIndices = Hash.new
		
		@indices.each do 
			| index |
			
			bacID = index.bacID
			numberOfPools = index.numPoolsWithAtLeast1Hit
			
			if(numberOfPools.to_i > (minNumberOfPoolsWithHits - 1))
				if(hashIndices.include?(bacID))
					arrIndex = hashIndices[bacID]
					arrIndex.push(index)
					hashIndices[bacID] = arrIndex
				else
					arrIndex = Array.new
					arrIndex.push(index)
					hashIndices[bacID] = arrIndex
				end
			end
		end #@indices.each do
				
		hashIndices.each do
			| key, arrIndex |
			if(arrIndex.length > 1)
				differentChrom = 0
				prevChrom = ""
							
				arrIndex.each do
					| index |
										
					chrom = index.idxChr
					indexStart = index.idxStart
					indexStop = index.idxEnd
										
					if(prevChrom == "")
						prevChrom = chrom
					end
					
					if(chrom != prevChrom)
						differentChrom = 1
						break
					end
					
					prevChrom = chrom
				end
								
				if(differentChrom == 1)
					arrIndex.each do
						| line |
									
						puts line.to_s
					end
				end
			end
		end #hashIndices.each do
	end #def findInterchromosomalBreakPoints
	
	def findIntrachromosomalBreakPoints(minNumberOfPoolsWithHits)
	
		#Hash for indices
		hashIndices = Hash.new
		
		@indices.each do 
			| index |
			
			bacID = index.bacID
			numberOfPools = index.numPoolsWithAtLeast1Hit
			
			if(numberOfPools.to_i > (minNumberOfPoolsWithHits - 1))
				if(hashIndices.include?(bacID))
					arrIndex = hashIndices[bacID]
					arrIndex.push(index)
					hashIndices[bacID] = arrIndex
				else
					arrIndex = Array.new
					arrIndex.push(index)
					hashIndices[bacID] = arrIndex
				end
			end
		end #@indices.each do
				
		hashIndices.each do
			| key, arrIndex |
			if(arrIndex.length > 1)
				differentChrom = 0
				prevChrom = ""
				arrIndexRange = Array.new
				
				arrIndex.each do
					| index |
										
					chrom = index.idxChr
					indexStart = index.idxStart
					indexStop = index.idxEnd
					
					arrIndexRange.push(indexStart.to_i..indexStop.to_i)
										
					if(prevChrom == "")
						prevChrom = chrom
					end
					
					if(chrom != prevChrom)
						differentChrom = 1
						break
					end
					
					prevChrom = chrom
				end
				
				differentRange = 0
								
				arrIndexRange.each do
					| range |
										
					arrIndexRange.each do
						| range2 |
					
						if (range.rangesOverlap?(range2) == false)
							differentRange = 1
						end
					end
				end
				
				if((differentChrom == 0) && (differentRange == 1))
					arrIndex.each do
						| line |
									
						puts(line.to_s)
					end
				end
			end
		end #hashIndices.each do
	end #def findIntrachromosomalBreakPoints
	
	def findAmbiguousMappings(outputFile)
		
		@indices.each do
			| index |
			
			if(@hashMappings.include?(index.bacID))
				arrIndex = @hashMappings[index.bacID]
				arrIndex.push(index)
				@hashMappings[index.bacID] = arrIndex
			else
				arrIndex = Array.new
				arrIndex.push(index)
				@hashMappings[index.bacID] = arrIndex
			end
		end #@indices.each do
		
		maxNumberOfMappings = 0
		
		@hashMappings.each do
			|bac, arrIndex|
			
			if (arrIndex.length > maxNumberOfMappings)
				maxNumberOfMappings = arrIndex.length
			end
		end
		
		i = 1
		writer = BRL::Util::TextWriter.new(outputFile,"w",false)
		
		while (i <= maxNumberOfMappings)
			
			@hashMappings.each do
				|bac, arrIndex|
				
				if (arrIndex.length == i)
					arrIndex.each do
						|index|
						writer.write("#{i}.mappings\t#{index}")
					end
				end
			end
			
			i += 1
		end
	end
	
	def removeOverlappedIndices(outputFile, highestIndexOrderToRemove=4)
		@hashMappings.each do
			|bac, arrIndex|
			
			if (arrIndex.length > 1)
				
				arrIndex.each do
					| multiIndex |
					
					# Only remove indices below highestIndexOrderToRemove
					if (multiIndex.numPoolsWithAtLeast1Hit.to_i <= highestIndexOrderToRemove)
					
						multiRange = (multiIndex.idxStart.to_i..multiIndex.idxEnd.to_i)
										
						@indices.each do
							| index |
							
							unless (index == multiIndex)
								range = (index.idxStart.to_i..index.idxEnd.to_i)
													
								#if they overlap
								if (multiIndex.idxChr == index.idxChr) && (range.rangesOverlap?(multiRange) == true)
									#if they share pools
									arrIntersection = multiIndex.poolIDs & index.poolIDs
																	
									if (arrIntersection.length > 0)
										puts multiIndex									
										@indices[@indices.index(multiIndex)] = nil
										break
									end
								end
							end
						end
						
						@indices.compact!
					end
				end
			end
		end
				
		writer = BRL::Util::TextWriter.new(outputFile,"w",false)
		
		@indices.each do 
			| tempIndex |
			
			writer.write(tempIndex.to_s)
		end
	end
	
	def findReadIndexOrder(highestIndexOrder=false)
		#Hash for indices
		hashReads = Hash.new
		
		@indices.each do 
			| index |
			
			arrReads = index.readList
			numberOfPools = index.numPoolsWithAtLeast1Hit
			
			arrReads.each do
				| read |
				
				if(hashReads.include?(read))
					arrIndex = hashReads[read]
					arrIndex.push(numberOfPools)
					hashReads[read] = arrIndex
				else
					arrIndex = Array.new
					arrIndex.push(numberOfPools)
					hashReads[read] = arrIndex
				end
			end
		end #@indices.each do
		
		hashReads.each do
			|read, pools|
			
			pools.sort!{|x,y| y <=> x }
			
			if highestIndexOrder==true
				highestIndex = pools[0]
				pools.clear
				pools.push(highestIndex)
			end
		end
		
		return hashReads
	end #readIndexOrder()
	
	def readIndexOrder(highestIndexOrder=false)
		hashIndexOrder = self.findReadIndexOrder(highestIndexOrder)
		
		hashIndexOrder.each do
			|read, pools|
			
			if highestIndexOrder==true
				puts read + " " + pools[0]	
			else
				puts read + " " + pools.join(",")
			end
		end
	end #readIndexOrder(highestIndexOrder=false)
	
	def removeDuplicateReads(outputFile)
		#Copy indices
		tempIndices = @indices
		hashHighestIndexOrder = self.findReadIndexOrder(true)
		
		# Remove duplicate reads
		tempIndices.each do 
			| tempIndex |
			
			numPoolsWithAtLeast1Hit = tempIndex.numPoolsWithAtLeast1Hit
			arrReads = tempIndex.readList
								
			arrReads.each do 
				| read |
				
				readHighestIndexOrder = hashHighestIndexOrder[read].to_s
				
				if(numPoolsWithAtLeast1Hit.to_i < readHighestIndexOrder.to_i)
					index = arrReads.index(read)
					tempIndex.readList[index] = nil
					tempIndex.readLengths[index] = nil
					tempIndex.readStarts[index] = nil
				end
				
			end #arrReads.each do
			
			tempIndex.readList.compact!
			tempIndex.readLengths.compact!
			tempIndex.readStarts.compact!
					
		end #tempIndices.each do
		
		writer = BRL::Util::TextWriter.new(outputFile,"w",false)
		
		#Recalculate index statistics
		tempIndices.each do
			| index |
			
			arrPools = index.poolIDs
			arrReads = index.readList
			index.numHitsPerPool.fill(0)
			
			arrayIndex = 0
						
			arrPools.each do
				| pool |
				
				arrReads.each do
					| read |
					
					if(read =~ /^#{pool}/) || (read =~ /^#{pool.upcase}/)
						index.numHitsPerPool[arrayIndex] = index.numHitsPerPool[arrayIndex] + 1	
					end
				end
				arrayIndex = arrayIndex + 1
			end
			
			poolsWithIndex = 0
			
			index.numHitsPerPool.each do
				| number |
				
				if(number.to_i > 0) 
					poolsWithIndex = poolsWithIndex + 1
				end
			end
			
			#Redetermine index start and stop
			arrReads = index.readList
			
			index.idxStart = index.readStarts.first
			index.idxEnd = index.readStarts.last.to_i + index.readLengths.last.to_i
			
			index.numPoolsWithAtLeast1Hit = poolsWithIndex
			
			if(poolsWithIndex > 1)
				writer.write(index.to_s)
			end
		end
	end #removeDuplicateReads
	
	def findBACIndexOrder(highestIndexOrder=false)
		#Hash for indices
		hashBAC = Hash.new
		
		@indices.each do 
			| index |
			
			bacID = index.bacID
			numberOfPools = index.numPoolsWithAtLeast1Hit
			
			if(hashBAC.include?(bacID))
				arrIndex = hashBAC[bacID]
				arrIndex.push(numberOfPools)
				hashBAC[bacID] = arrIndex
			else
				arrIndex = Array.new
				arrIndex.push(numberOfPools)
				hashBAC[bacID] = arrIndex
			end
			
		end #@indices.each do
		
		hashBAC.each do
			|bac, pools|
			
			pools.sort!{|x,y| y <=> x }
			
			if highestIndexOrder==true
				highestIndex = pools[0]
				pools.clear
				pools.push(highestIndex)
			end
		end
		
		return hashBAC
	end #readIndexOrder()
	
	def bacIndexOrder(highestIndexOrder=false)
		hashIndexOrder = self.findBACIndexOrder(highestIndexOrder)
		
		hashIndexOrder.each do
			|bac, pools|
			
			if highestIndexOrder==true
				puts bac + " " + pools[0]	
			else
				puts bac + " " + pools.join(",")
			end
		end
	end #bacIndexOrder(highestIndexOrder=false)
	
	def removeDuplicateIndices(outputFile)
		#Copy indices
		tempIndices = @indices
		hashHighestIndexOrder = self.findBACIndexOrder(true)
		
		# Remove duplicate reads
		index = 0
		
		tempIndices.each do 
			| tempIndex |
			
			bacID = tempIndex.bacID
			numPoolsWithAtLeast1Hit = tempIndex.numPoolsWithAtLeast1Hit
									
			bacHighestIndexOrder = hashHighestIndexOrder[bacID].to_s
			
			if(numPoolsWithAtLeast1Hit < bacHighestIndexOrder)
				tempIndices[index] = nil
			end
						
			index = index + 1
						
		end #tempIndices.each do
		
		tempIndices.compact!
		
		writer = BRL::Util::TextWriter.new(outputFile,"w",false)
		
		tempIndices.each do 
			| tempIndex |
			
			writer.write(tempIndex.to_s)
		end
	end #removeDuplicateIndices
	
	def removeReads(minNumOfHitsInPool, maxIndexOrderToRemoveReadFrom, outputFile)
		maxIndexOrderToRemoveReadFrom = maxIndexOrderToRemoveReadFrom + 1
		
		#Copy indices
		tempIndices = @indices
				
		# Remove reads
		tempIndices.each do 
			| tempIndex |
			
			arrNumHitsPerPool = tempIndex.numHitsPerPool
			arrPools = tempIndex.poolIDs
			numPoolsWithAtLeast1Hit = tempIndex.numPoolsWithAtLeast1Hit
			arrReads = tempIndex.readList
						
			poolIndex = 0
			poolsWithHits = 0
			
			if(numPoolsWithAtLeast1Hit.to_i < maxIndexOrderToRemoveReadFrom.to_i) 
							
				arrNumHitsPerPool.each do 
					| hits |
													
					if(hits.to_i < minNumOfHitsInPool.to_i)
						tempIndex.numHitsPerPool[poolIndex] = 0
						
						pool = arrPools[poolIndex]
						
						readIndex = 0
						
						arrReads.each do
							| read |
														
							if(read =~ /^#{pool.upcase}/)
								tempIndex.readList.delete(read)
								tempIndex.readLengths.delete_at(readIndex)
								tempIndex.readStarts.delete_at(readIndex)
							end
							readIndex = readIndex + 1
						end
					else
						poolsWithHits = poolsWithHits + 1
					end
					
					poolIndex = poolIndex + 1
					
				end #arrNumHitsPerPool.each do
				
				tempIndex.numPoolsWithAtLeast1Hit = poolsWithHits
			end
		end #tempIndices.each do
		
		writer = BRL::Util::TextWriter.new(outputFile,"w",false)
		
		tempIndices.each do 
			| tempIndex |
			
			if(tempIndex.numPoolsWithAtLeast1Hit.to_i > 1)
				writer.write(tempIndex.to_s)
			end
		end
	end #removeReads
	
	def removeNonmatchedMatepairs(outputFile)
		#Copy indices
		tempIndices = @indices
		hashMatePair = self.makeMatePairHash()
		
		# Remove nonmatched reads
		tempIndices.each do 
			| tempIndex |
			
			arrReads = tempIndex.readList
						
			arrReads.each do 
				| read |
				
				#This if removes only matepairs where both matepairs are present
				if (hashMatePair[read] == 1)
					direction = read[6, 1]
					boMatchedMatePair = 0
					
					matepair = ""
					
					# Forward Read
					if (direction == "D")
						matepair = read.dup
						matepair.gsub!(/^(.{6})(.)/, '\1E')
						
						if arrReads.include?(matepair) 
							boMatchedMatePair = 1
						end
					# Reverse Read
					elsif (direction == "E")
						matepair = read.dup
						matepair.gsub!(/^(.{6})(.)/, '\1D')
						
						if arrReads.include?(matepair) 
							boMatchedMatePair = 1
						end
					end
									
					if(boMatchedMatePair == 0)
						index = arrReads.index(read)
						tempIndex.readList[index] = nil
						tempIndex.readLengths[index] = nil
						tempIndex.readStarts[index] = nil
					end
				end
				
			end #arrReads.each do
			
			tempIndex.readList.compact!
			tempIndex.readLengths.compact!
			tempIndex.readStarts.compact!
					
		end #tempIndices.each do
		
		writer = BRL::Util::TextWriter.new(outputFile,"w",false)
		
		#Recalculate index statistics
		tempIndices.each do
			| index |
			
			arrPools = index.poolIDs
			arrReads = index.readList
			index.numHitsPerPool.fill(0)
			
			arrayIndex = 0
						
			arrPools.each do
				| pool |
				
				arrReads.each do
					| read |
					
					if(read =~ /^#{pool.upcase}/)
						index.numHitsPerPool[arrayIndex] = index.numHitsPerPool[arrayIndex] + 1	
					end
				end
				arrayIndex = arrayIndex + 1
			end
			
			poolsWithIndex = 0
			
			index.numHitsPerPool.each do
				| number |
				
				if(number.to_i > 0) 
					poolsWithIndex = poolsWithIndex + 1
				end
			end
			
			#Redetermine index start and stop
			arrReads = index.readList
			
			index.idxStart = index.readStarts.first
			index.idxEnd = index.readStarts.last.to_i + index.readLengths.last.to_i
			
			index.numPoolsWithAtLeast1Hit = poolsWithIndex
			
			if(poolsWithIndex > 1)
				writer.write(index.to_s)
			end
		end
	end #removeNonmatchedMatepairs(outputFile)
	
	def makeMatePairHash()
	
		hashMatePair = Hash.new
		
		@indices.each do
			| index |
			
			arrReads = index.readList
			
			arrReads.each do
				| read |
				
				hashMatePair[read] = 0
			end
		end
		
		hashMatePair.each do
			| read, boMatepair |
			
			direction = read[6, 1]
			
			matepair = ""
			
			# Forward Read
			if (direction == "D")
				matepair = read.dup
				matepair.gsub!(/^(.{6})(.)/, '\1E')
				
				if hashMatePair.has_key?(matepair) 
					hashMatePair[read] = 1
				end
			# Reverse Read
			elsif (direction == "E")
				matepair = read.dup
				matepair.gsub!(/^(.{6})(.)/, '\1D')
				
				if hashMatePair.has_key?(matepair) 
					hashMatePair[read] = 1
				end
			end
		end
		
		return hashMatePair
	end
	
	
	def removeIndicesBasedOn1Pool(minNumOfHitsInPool, maxIndexOrderToRemoveReadFrom)
		maxIndexOrderToRemoveReadFrom = maxIndexOrderToRemoveReadFrom + 1
		
		#Copy indices
		tempIndices = @indices
				
		indexTempIndex = 0
		
		# Remove reads
		tempIndices.each do 
			| tempIndex |
			
			arrNumHitsPerPool = tempIndex.numHitsPerPool
			numPoolsWithAtLeast1Hit = tempIndex.numPoolsWithAtLeast1Hit
									
			if(numPoolsWithAtLeast1Hit.to_i < maxIndexOrderToRemoveReadFrom.to_i) 
							
				indexHits = 1
				
				arrNumHitsPerPool.each do 
					| hits |
																		
					if(hits.to_i < minNumOfHitsInPool.to_i)
												
						if (indexHits == @numberOfPools)
							tempIndices[indexTempIndex] = nil
						end
					else
						break
					end
					
					indexHits = indexHits + 1
					
				end #arrNumHitsPerPool.each do
			end
			
			indexTempIndex = indexTempIndex + 1
		end #tempIndices.each do
		
		tempIndices.compact!
		
		tempIndices.each do 
			| tempIndex |
			
			if(tempIndex.numPoolsWithAtLeast1Hit.to_i > 1)
				puts tempIndex.to_s
			end
		end
	end #removeDuplicateReads
	
	def removeIndices(minNumOfHitsInPool, maxIndexOrderToRemoveReadFrom, outputFile)
		maxIndexOrderToRemoveReadFrom = maxIndexOrderToRemoveReadFrom + 1
		
		#Copy indices
		tempIndices = @indices
				
		indexTempIndex = 0
		
		# Remove reads
		tempIndices.each do 
			| tempIndex |
			
			arrNumHitsPerPool = tempIndex.numHitsPerPool
			numPoolsWithAtLeast1Hit = tempIndex.numPoolsWithAtLeast1Hit
									
			if(numPoolsWithAtLeast1Hit.to_i < maxIndexOrderToRemoveReadFrom.to_i) 
							
				indexHits = 1
				
				arrNumHitsPerPool.each do 
					| hits |
																		
					if(hits.to_i < minNumOfHitsInPool.to_i)
												
						if (indexHits == @numberOfPools)
							tempIndices[indexTempIndex] = nil
						end
					end
										
					indexHits = indexHits + 1
					
				end #arrNumHitsPerPool.each do
			end
			
			indexTempIndex = indexTempIndex + 1
		end #tempIndices.each do
		
		tempIndices.compact!
		
		writer = BRL::Util::TextWriter.new(outputFile,"w",false)
		
		tempIndices.each do 
			| tempIndex |
			
			if(tempIndex.numPoolsWithAtLeast1Hit.to_i > 1)
				writer.write(tempIndex.to_s)
			end
		end
	end #removeDuplicateReads
	
	def uniqueIndicesByOrder(minNumOfHitsInPool, maxIndexOrderToRemoveReadFrom)
		maxIndexOrderToRemoveReadFrom = maxIndexOrderToRemoveReadFrom + 1
		
		#Copy indices
		tempIndices = @indices
				
		# Remove reads
		tempIndices.each do 
			| tempIndex |
			
			arrNumHitsPerPool = tempIndex.numHitsPerPool
			arrPools = tempIndex.poolIDs
			numPoolsWithAtLeast1Hit = tempIndex.numPoolsWithAtLeast1Hit
			arrReads = tempIndex.readList
						
			poolIndex = 0
			poolsWithHits = 0
			
			if(numPoolsWithAtLeast1Hit.to_i < maxIndexOrderToRemoveReadFrom.to_i) 
							
				arrNumHitsPerPool.each do 
					| hits |
													
					if(hits.to_i < minNumOfHitsInPool.to_i)
						tempIndex.numHitsPerPool[poolIndex] = 0
						
						pool = arrPools[poolIndex]
						
						readIndex = 0
						
						arrReads.each do
							| read |
														
							if(read =~ /^#{pool.upcase}/)
								tempIndex.readList.delete(read)
								tempIndex.readLengths.delete_at(readIndex)
								tempIndex.readStarts.delete_at(readIndex)
							end
							readIndex = readIndex + 1
						end
					else
						poolsWithHits = poolsWithHits + 1
					end
					
					poolIndex = poolIndex + 1
					
				end #arrNumHitsPerPool.each do
				
				tempIndex.numPoolsWithAtLeast1Hit = poolsWithHits
			end
		end #tempIndices.each do
		
		tempIndices.each do 
			| tempIndex |
			
			if(tempIndex.numPoolsWithAtLeast1Hit.to_i > 1)
				puts tempIndex.to_s
			end
		end
	end #uniqueIndicesByOrder
	
	def mergeOverlappingIndices(outputFile)
		@hashMappings.each do
			|bac, arrIndex|
			
			@newIndex = nil
			
			if (arrIndex.length > 1)
			
				arrIndex.each do
					| index |
					
					range = (index.idxStart.to_i..index.idxEnd.to_i)
					j = 0				
					arrIndex.each do
						|targetIndex|
						
						unless (index == targetIndex)
							#if they share pools
							arrIntersection = index.poolIDs & targetIndex.poolIDs
						
							if (arrIntersection.length == 4)
								targetRange = (targetIndex.idxStart.to_i..targetIndex.idxEnd.to_i)
																				
								#if they overlap
								if (index.idxChr == targetIndex.idxChr) && (range.rangesOverlap?(targetRange) == true)
									if (@newIndex == nil)
										@newIndex = BRL::PGI::PGIIndex.new(index.to_s,@numberOfPools)
									end
									
									if (targetIndex.idxStart.to_i <= @newIndex.idxStart.to_i)
										@newIndex.idxStart = targetIndex.idxStart
									end
									if (index.idxStart.to_i <= @newIndex.idxStart.to_i)
										@newIndex.idxStart = index.idxStart
									end
									
									if (targetIndex.idxEnd.to_i >= @newIndex.idxEnd.to_i)
										@newIndex.idxEnd = targetIndex.idxEnd
									end
									if (index.idxEnd.to_i >= @newIndex.idxEnd.to_i)
										@newIndex.idxEnd = index.idxEnd
									end

									if (targetIndex.idxWindowStart.to_i <= @newIndex.idxWindowStart.to_i)
										@newIndex.idxWindowStart = targetIndex.idxWindowStart
									end
									if (index.idxWindowStart.to_i <= @newIndex.idxWindowStart.to_i)
										@newIndex.idxWindowStart = index.idxWindowStart
									end
									
									if (targetIndex.idxWindowEnd >= @newIndex.idxWindowEnd)
										@newIndex.idxWindowEnd = targetIndex.idxWindowEnd
									end
									if (index.idxWindowEnd.to_i >= @newIndex.idxWindowEnd.to_i)
										@newIndex.idxWindowEnd = index.idxWindowEnd
									end
								
									arrNewReads = Array.new
									arrNewLengths = Array.new
									arrNewReadStart = Array.new
									
									arrNewReads = @newIndex.readList + index.readList + targetIndex.readList
									arrNewReads.uniq!
									@newIndex.readList = arrNewReads
									
									arrNewLengths = @newIndex.readLengths + index.readLengths + targetIndex.readLengths
									arrNewLengths.uniq!
									@newIndex.readLengths = arrNewLengths
									
									arrNewReadStart = @newIndex.readStarts + index.readStarts + targetIndex.readStarts
									arrNewReadStart.uniq!
									@newIndex.readStarts = arrNewReadStart
									
									i = 0
									
									index.poolIDs.each do
										|poolID|
										
										hitCount = 0
										
										arrNewReads.each do
											|read|
											
											if (read.include?(poolID.upcase))
												hitCount += 1
											end
										end
										
										@newIndex.numHitsPerPool[i] = hitCount
										
										i += 1
									end
									
									targetIndex.bacID = nil
								end
							end
						end
						j += 1
					end
				end
				
				unless (@newIndex == nil)
					@indices.push(@newIndex)
				end
			end
		end
		
		writer = BRL::Util::TextWriter.new(outputFile,"w",false)
		
		@indices.each do 
			| tempIndex |
			
			unless (tempIndex.bacID.nil?)
				writer.write(tempIndex.to_s)
			end
		end	
	end
	
end #DeconvolutionUtil

class ControlAnalysis
	
	def rankReads(inputFile)
	
		if (FileTest.exists?(inputFile))
			#Open file for reading
			reader = BRL::Util::TextReader.new(inputFile)
		else
			raise "\nERROR: File #{inputFile} does not exist.\n"
		end
		
		hashReads = Hash.new
		
		reader.each do
			| line |
			
			line.chomp!
			arrLine = line.split(/\s+/)
			
			strReads = arrLine[7]
			
			arrReads = strReads.split(/,/)
		
			arrReads.each do
				| read |
				
				hashReads[read] = arrLine[2] + "\t" + arrLine[3]
			end
		end
		
		hashReads.each do
			| read, data |
			
			puts(read + "\t" + data)
		
		end
	
	end #def rankReads()
end #


end; end #module BRL; module PGI
