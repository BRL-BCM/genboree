require 'brl/util/textFileUtil'
require 'brl/util/util'


unless (ARGV.empty?)
	if(ARGV.include?"-h")
		puts "The following commands are available to AlignStreamSummaryStats:\n\n"
		puts "-h     This help message.\n"
		puts "-f     Align Stream Summary file to analyze.\n"
		puts "-o     Output file.\n"
	elsif((ARGV.include?"-f") || (ARGV.include?"-o"))
		switch = ARGV.index("-f")
		file = ARGV.at(switch + 1)
		
		switch = ARGV.index("-o")
		output = ARGV.at(switch + 1)
	else
		raise "\nIncorrect argument to AlignStreamSummaryStats.\n"
	end
end

comparison = 0
gene = ""
totalHuman_ChimpGenes = 0
totalHuman_RhesusGenes = 0
totalHuman_MouseGenes = 0
totalHuman_RatGenes = 0
totalChimp_RhesusGenes = 0
totalChimp_MouseGenes = 0
totalChimp_RatGenes = 0
totalRhesus_MouseGenes = 0
totalRhesus_RatGenes = 0
totalMouse_RatGenes = 0
doStats = 0

hashSummary = Hash.new

hashBin = Hash.new
arrGenes = Array.new
hashBin["90"] = arrGenes
arrGenes = Array.new
hashBin["80"] = arrGenes
arrGenes = Array.new
hashBin["70"] = arrGenes
arrGenes = Array.new
hashBin["60"] = arrGenes
arrGenes = Array.new
hashBin["50"] = arrGenes

reader = BRL::Util::TextReader.new(file)

reader.each do
	|line|
	
	line.chomp!
	
	if (line =~ /^>/)
		doStats = 1
		
		if (line =~ /.+hg16.+/) && (line =~ /.+panTro1.+/)
			comparison = "hg16-panTro1"
		elsif (line =~ /.+hg16.+/) && (line =~ /.+rm1.+/)
			comparison = "hg16-rm1"
		elsif (line =~ /.+hg16.+/) && (line =~ /.+mm4.+/)
			comparison = "hg16-mm4"
		elsif (line =~ /.+hg16.+/) && (line =~ /.+rn3\.1.+/)
			comparison = "hg16-rn3.1"
		elsif (line =~ /.+panTro1.+/) && (line =~ /.+rm1.+/)
			comparison = "panTro1-rm1"
		elsif (line =~ /.+panTro1.+/) && (line =~ /.+mm4.+/)
			comparison = "panTro1-mm4"
		elsif (line =~ /.+panTro1.+/) && (line =~ /.+rn3\.1.+/)
			comparison = "panTro1-rn3.1"
		elsif (line =~ /.+rm1.+/) && (line =~ /.+mm4.+/)
			comparison = "rm1-mm4"
		elsif (line =~ /.+rm1.+/) && (line =~ /.+rn3\.1.+/)
			comparison = "rm1-rn3.1"
		elsif (line =~ /.+mm4.+/) && (line =~ /.+rn3\.1.+/)
			comparison = "mm4-rn3.1"
		end
		
		index = line.index("NM_")
		
		if (index == nil)
			gene = "NA"
		else
			gene = line.slice(index..(index + 8))
		end
	else
		arrSplit = line.split(/\s+/)
		stat = arrSplit[0]
		data = arrSplit[1].to_f
		
		if (stat == "CDSconserved:")
			if (data > 0.60)
				doStats = 1
				
				if comparison == "hg16-panTro1"
					totalHuman_ChimpGenes += 1
				elsif comparison == "hg16-rm1"
					totalHuman_RhesusGenes += 1
				elsif comparison == "hg16-mm4"
					totalHuman_MouseGenes += 1
				elsif comparison == "hg16-rn3.1"
					totalHuman_RatGenes += 1
				elsif comparison == "panTro1-rm1"
					totalChimp_RhesusGenes += 1
				elsif comparison == "panTro1-mm4"
					totalChimp_MouseGenes += 1
				elsif comparison == "panTro1-rn3.1"
					totalChimp_RatGenes += 1
				elsif comparison == "rm1-mm4"
					totalRhesus_MouseGenes += 1
				elsif comparison == "rm1-rn3.1"
					totalRhesus_RatGenes += 1
				elsif comparison == "mm4-rn3.1"
					totalMouse_RatGenes += 1
				end
			else
				doStats = 0
			end
			
			if (data > 0.90)
			hashBin["90"].push("#{gene}\t#{comparison}\t#{data}")
			elsif (data > 0.80)
				hashBin["80"].push("#{gene}\t#{comparison}\t#{data}")
			elsif (data > 0.70)
				hashBin["70"].push("#{gene}\t#{comparison}\t#{data}")
			elsif (data > 0.60)
				hashBin["60"].push("#{gene}\t#{comparison}\t#{data}")
			elsif (data > 0.50)
				hashBin["50"].push("#{gene}\t#{comparison}\t#{data}")
			end		
			
		end
		
		if (doStats == 1)
			if hashSummary.has_key?(comparison)
				hashData = hashSummary[comparison]
				
				if hashData.has_key?(stat)
					hashData[stat] = hashData[stat] + data
				else
					hashData[stat] = data
				end
				
				hashSummary[comparison] = hashData
			else
				hashData = Hash.new
				
				hashData[stat] = data
				
				hashSummary[comparison] = hashData
			end
		end
	end	
end

hashSummary.each do
	| comparison, hashData |
	
	puts comparison
	
	totalGenes = 0
	
	if comparison == "hg16-panTro1"
		totalGenes = totalHuman_ChimpGenes 
	elsif comparison == "hg16-rm1"
		totalGenes = totalHuman_RhesusGenes 
	elsif comparison == "hg16-mm4"
		totalGenes = totalHuman_MouseGenes 
	elsif comparison == "hg16-rn3.1"
		totalGenes = totalHuman_RatGenes 
	elsif comparison == "panTro1-rm1"
		totalGenes = totalChimp_RhesusGenes 
	elsif comparison == "panTro1-mm4"
		totalGenes = totalChimp_MouseGenes 
	elsif comparison == "panTro1-rn3.1"
		totalGenes = totalChimp_RatGenes 
	elsif comparison == "rm1-mm4"
		totalGenes = totalRhesus_RatGenes 
	elsif comparison == "rm1-rn3.1"
		totalGenes = totalRhesus_RatGenes 		
	elsif comparison == "mm4-rn3.1"
		totalGenes = totalMouse_RatGenes
	end
	
	puts "TotalGenes:	#{totalGenes}"
	
	hashData.each do
		| stat, data |
		
		average = data/totalGenes.to_f
		
		puts "#{stat}\t#{average}"
	end
end

hashBin.each do
	|percent, arrGenes|
	
	puts "Percent identity: #{percent}"
	
	arrGenes.each do
		| gene |
		
		puts gene
	end
end

