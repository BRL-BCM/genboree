#!/usr/bin/env ruby

require 'brl/go/go'
require 'brl/go/goNode'
require 'rgl/adjacency'

# Check for appropriate command-line arguments. 
# TO DO: Better system for processing arguments. 
# TO DO: Flag arguments for specifying which subtrees to use. 
# Case where the only argument is a file name. 
if (ARGV.length == 1)
# Store the filename. 
	filename=ARGV[0]
# Set the read-from-file flag to false. 
	readFromFile=fasle
# Case where we have a filename and a read-from-file flag. 
elsif (ARGV.length == 2)
# Set the read-from-file flag. 
	if (ARGV[0]=='-f')
		readFromFile=true;
	end
# Store the filename. 
	filename=ARGV[1]
# Not the right number of arguments. Print a usage statement. 
else
	print ("usage: #{$0} [-f] genelist\n")
	exit
end

# TO DO: Change GO module to specify a generic user. 
# Prepare the GO tree for use. 
# If the -f flag is set, read the tree from a file. 
if (readFromFile==true)
	puts "Reading GO tree from file..."
	mol, bio, cel=Marshal.load(File.open("rgl_dump"))
# Otherwise, read the tree from the database
else
	puts "Reading GO tree from database..."
	mol, bio, cel=GO.load_rgl
end

# TO DO: Change GO module to specify a generic user. 
# Prepare the GO tree for use. 
# If the -f flag is set, read the tree from a file. 
if (readFromFile==true)
	puts "Reading gene products from file..."
	gp=Marshal.load(File.open("gp_dump"))
# Otherwise, read the tree from the database
else
	puts "Reading gene products from database..."
	gp=GO.associate_geneProducts
end

# Store the size of the population of genes for later use
populationGeneNumber=gp.size

# Associate the gene products with the GO terms. 
puts "Associating gene products with the GO tree..."
puts "\tMolecular function..."
GO.addGeneProducts(gp, mol)
puts "\tBiological process..."
GO.addGeneProducts(gp, bio)
puts "\tCell component..."
GO.addGeneProducts(gp, cel)

# Initialize the count of genes in the experimental set and file set to 0. 
experimentGeneNumber=0
fileGeneNumber=0

# Make a hash to associate term ids with term objects. 
termsHash=Hash.new
mol.each_vertex { |v|
	termsHash[v.id]=v
}
bio.each_vertex { |v|
	termsHash[v.id]=v
}
cel.each_vertex { |v|
	termsHash[v.id]=v
}

# Make a hash to store each term that is found. 
experimentTerms=Hash.new

# Open the file for the list of experiment genes. 
experimentList=File.new(filename, "r");
# TO ADD: error checking for file oepning

puts "Processing input file..."

# Read the file into an array. 
experimentArray=experimentList.readlines
# Close the file. 
experimentList.close
# Remove version information from accession numbers. 
experimentArray.each { |item|
	item=~/(\S+)(?:\.\S+)?$/
	item=$1
}
# Strip newlines and whitespace. 
experimentArray.map! { |item| item.strip }
# Remove duplicate entries. 
experimentArray.uniq!

# Make an output file for genes we can't find. 
notFound=File.new("notfound.txt", "w");

# For each gene in the experiment list: 
experimentArray.each { |geneID|
	# Check to see if the gene is in the GO database. 
	if(currentGP=gp[geneID])
		# Increment gene count if the gene was found in the database. 
		experimentGeneNumber+=1
		# Get list of terms. 
		# For each term associated with gene: 
		currentGP.term_ids.each{ |termID|
			# If term is key in sample hash: 
			if (experimentTerms.has_key?(termsHash[termID]))
				# increment sample hash value for term
				experimentTerms[termsHash[termID]]+=1
			# Otherwise, 
			else
				# set sample hash value to one for term
				experimentTerms[termsHash[termID]]=1
			end
		}
	else
		notFound.print(geneID, "\n")
	end
	fileGeneNumber+=1
}
# Close the file of genes we can't find. 
notFound.close

# Find out how many times each term appears in the database. 
# TO DO: If there is a way to do this for just the necessary terms, rather than every term, speed would be increased considerably, but this is not practical in the current implementation of the API. 
puts ("Analyzing population genes...")
# Make a hash to store the number of genes associated with each term. 
populationTerms=Hash.new
# For each gene in the database: 
gp.each_value { |gene|
	# For each term associated with the current gene: 
	gene.term_ids.each{ |termID|
		# If the term is a key in the population hash: 
		if (populationTerms.has_key?(termsHash[termID]))
			# Increment the population hash value for the term. 
			populationTerms[termsHash[termID]]+=1
		# Otherwise: 
		else
			# Make a new entry for the current term and set its count to 1. 
			populationTerms[termsHash[termID]]=1
		end
	}
}

puts ("Creating output file and calculating statistics...")
# Make an output file. 
outFile=File.new("results.txt", "w")

# Output how many of the submitted genes were used in the test. 
outFile.print("Found: #{experimentGeneNumber}/#{fileGeneNumber} genes\n")

# Print the column headings. 
outFile.print ("Term\tSample Hits\tSample Total\tSample Ratio\tPopulation Hits\tPopulation Total\tPopulation Ratio\tSample to Population Ratio\tEnrichment\tCorrected Enrichment\n")

# Pre-compute all factorials that we need. 
GO.buildFactTable(populationGeneNumber)

# For each term that is a key in the sample hash
experimentTerms.each_key { |term|
	# Print: 
	# term
	outFile.print (term.name, "\t")
	# number of genes in sample for that term
	outFile.print (experimentTerms[term], "\t")
	# number of genes in sample
	outFile.print (experimentGeneNumber, "\t")
	# ratio of above two lines
	outFile.print (experimentRatio=experimentTerms[term].to_f/experimentGeneNumber, "\t")
	# number of genes in population for that term
	outFile.print (populationTerms[term], "\t")
	# number of genes in population
	outFile.print (populationGeneNumber, "\t")
	# ratio of above two terms
	outFile.print (populationRatio=populationTerms[term].to_f/populationGeneNumber, "\t")
	# ratio of above two ratios
	outFile.print (experimentRatio/populationRatio, "\t")
	# enrichment value
	outFile.print (p=GO.pvalue(populationGeneNumber, populationTerms[term], experimentGeneNumber, experimentTerms[term]), "\t")
	# Bonferroni corrected enrichment value
	outFile.print ([p*experimentTerms.size, 1].min, "\t")
	# end the line
	outFile.print ("\n")
}

# Cose the output file since we're done with it. 
outFile.close