#!/usr/bin/env ruby
$VERBOSE = 1

=begin
This file implements the class UcscExporter within the *BRL::SQL* module.

*UcscExporter* uses the class SqlToFile to export data from a UCSC database table to a LFF format text file
named the same as the exported table.  

*UcscExporter* has the following settable properties:
	dbrcFile - The location of a dbrc file containing login information for the database.
	humanDB - The name of the UCSC human database.
	mouseDB - The name of the UCSC mouse database.
	ratDB - The name of the UCSC rat database.
	humanDir - The directory in which LFF files from the human database are placed.
	mouseDir - The directory in which LFF files from the mouse database are placed.
	ratDir - The directory in which LFF files from the rat database are placed.
	doGzip - Gzip the output file.  True or false.
	
Three methods allow for export of UCSC data from tables that use three different schemas:
	genePrediction - acembly, ensGene, geneid, genieAlt, genScan, genscanSubopt, refGene, sanger20, sanger22, 
		softberryGene, tigrGeneIndex, twinscan, and similar tables
	genePredictionFlat - A version of genePrediction that associates the gene name with the gene prediction information.
	mRNA_EST_Blat - chrN_blatMouse, chrN_blatFish, chrN_blatHuman, chrN_mrna, chrN_est, chrN_intronEst, chimpBac, 
		chimpBlat, blastzBestMouse, blastzTightMouse, all_mrna, all_est uniGene, xenoEst and xenoMrna tables
Further information regarding UCSC schemas is available at:
	http://genome.ucsc.edu/goldenPath/gbdDescriptions.html
	
The three methods each take the following five arguments:
	database - The database from which the data is exported. Values:
		human - Export from human database.
		mouse - Export from mouse database.
		rat - Export from rat database.
		all - Export from the above three databases.
	table - The name of the table to be exported from the database.  If the table name is in the chrN format each 
		table will be exported.
	classId - The class to be included in the LFF file.
	type - The type to be included in the LFF file.
	subtype - The subtype to be included in the LFF file.

Author: Alan Harris <rharris1@bcm.tmc.edu>
Date  : March 13, 2003
=end

require 'sqlToFile'

module BRL; module SQL

class UcscExporter
	attr_accessor :dbrcFile, :humanDB, :mouseDB, :ratDB, :humanDir, :mouseDir, :ratDir, :doGzip

	def initialize
		@dbrcFile = "/users/hgsc/rharris1/.dbrc.rharris1"

		@humanDB = "andrewj_ucsc_hg13"
		@mouseDB = "andrewj_ucsc_mm2"
		@ratDB = "andrewj_ucsc_rn1"

		@humanDir = "/users/hgsc/rharris1/work/brl-depot/rharris1/ucscLFF/hg13/"
		@mouseDir = "/users/hgsc/rharris1/work/brl-depot/rharris1/ucscLFF/mm2/"
		@ratDir = "/users/hgsc/rharris1/work/brl-depot/rharris1/ucscLFF/rn1/"
		
		@doGzip = false
	end
	
	def genePrediction(database,table,classID,type,subtype)
		classID = '"' + classID + '"'
		type = '"' + type + '"'
		subtype = '"' + subtype + '"'
				
		genePredictionMap = ["Source Op Dest","#{classID} constant class","name -> name","#{type} constant type","#{subtype} constant subtype","chrom -> ref","exonStarts -> start","exonEnds -> stop","strand -> strand",'"." constant phase','"." constant score']
		
		mapper = BRL::SQL::SqlToFile.new(genePredictionMap)
		
		if (@doGzip == true)
			fileName = table + ".gz"
		else
			fileName = table
		end

		#Human Database
		if (database == "human")
			mapper.output(@dbrcFile,@humanDB,table,"#{@humanDir}#{fileName}",@doGzip,"chrom","name","exonCount","exonStarts","exonEnds")
		end

		#Mouse Database
		if (database == "mouse")
			mapper.output(@dbrcFile,@mouseDB,table,"#{@mouseDir}#{fileName}",@doGzip,"chrom","name","exonCount","exonStarts","exonEnds")
		end
				
		#Rat Database
		if (database == "rat")
			mapper.output(@dbrcFile,@ratDB,table,"#{@ratDir}#{fileName}",@doGzip,"chrom","name","exonCount","exonStarts","exonEnds")
		end
		
		#All Databases
		if(database == "all")
			mapper.output(@dbrcFile,@humanDB,table,"#{@humanDir}#{fileName}",@doGzip,"chrom","name","exonCount","exonStarts","exonEnds")
			mapper.output(@dbrcFile,@mouseDB,table,"#{@mouseDir}#{fileName}",@doGzip,"chrom","name","exonCount","exonStarts","exonEnds")
			mapper.output(@dbrcFile,@ratDB,table,"#{@ratDir}#{fileName}",@doGzip,"chrom","name","exonCount","exonStarts","exonEnds")
		end
	end
	
	def genePredictionFlat(database,table,classID,type,subtype)
		classID = '"' + classID + '"'
		type = '"' + type + '"'
		subtype = '"' + subtype + '"'
				
		genePredictionFlatMap = ["Source Op Dest","#{classID} constant class","geneName -> name","#{type} constant type","#{subtype} constant subtype","chrom -> ref","exonStarts -> start","exonEnds -> stop","strand -> strand",'"." constant phase','"." constant score'] 
		
		mapper = BRL::SQL::SqlToFile.new(genePredictionFlatMap)
		
		if (@doGzip == true)
			fileName = table + ".gz"
		else
			fileName = table
		end

		#Human Database
		if (database == "human")
			mapper.output(@dbrcFile,@humanDB,table,"#{@humanDir}#{fileName}",@doGzip,"chrom","geneName","exonCount","exonStarts","exonEnds")
		end

		#Mouse Database
		if (database == "mouse")
			mapper.output(@dbrcFile,@mouseDB,table,"#{@mouseDir}#{fileName}",@doGzip,"chrom","geneName","exonCount","exonStarts","exonEnds")
		end
		
		#Rat  Database
		if(database == "rat")
			mapper.output(@dbrcFile,@ratDB,table,"#{@ratDir}#{fileName}",@doGzip,"chrom","geneName","exonCount","exonStarts","exonEnds")
		end
		
		if(database == "all")
			mapper.output(@dbrcFile,@humanDB,table,"#{@humanDir}#{fileName}",@doGzip,"chrom","geneName","exonCount","exonStarts","exonEnds")
			mapper.output(@dbrcFile,@mouseDB,table,"#{@mouseDir}#{fileName}",@doGzip,"chrom","geneName","exonCount","exonStarts","exonEnds")
			mapper.output(@dbrcFile,@ratDB,table,"#{@ratDir}#{fileName}",@doGzip,"chrom","geneName","exonCount","exonStarts","exonEnds")
		end
	end
	
	def mRNA_EST_Blat(database,table,classID,type,subtype)
		
		classID = '"' + classID + '"'
		type = '"' + type + '"'
		subtype = '"' + subtype + '"'

		mRNA_EST_BlatMap = ["Source Op Dest","#{classID} constant class","qName -> name","#{type} constant type","#{subtype} constant subtype","tName -> ref","tStarts -> start","blockSizes -> stop","strand -> strand",'"." constant phase','matches -> score',"qStarts -> tstart","blockSizes -> tend"] 
		
		mapper = BRL::SQL::SqlToFile.new(mRNA_EST_BlatMap)
		
		if (table =~ /^chrN/)
			chrom = 1
			
			#Chromosomes 1-22
			while (chrom < 23)  do
				tableIncrement = table.gsub(/N/,chrom.to_s)
				
				if (@doGzip == true)
					fileName = tableIncrement + ".gz"
				else
					fileName = tableIncrement
				end
				
				#Human Database
				if(database == "human")
					mapper.output(@dbrcFile,@humanDB,tableIncrement,"#{@humanDir}#{fileName}",@doGzip,"tName","qName","blockCount","tStarts","blockSizes","qStarts","blockSizes",true)
				end
				
				#Mouse Database
				if(database == "mouse")
					mapper.output(@dbrcFile,@mouseDB,tableIncrement,"#{@mouseDir}#{fileName}",@doGzip,"tName","qName","blockCount","tStarts","blockSizes","qStarts","blockSizes",true)
				end
				
				#Rat Database
				if(database == "rat")
					mapper.output(@dbrcFile,@ratDB,tableIncrement,"#{@ratDir}#{fileName}",@doGzip,"tName","qName","blockCount","tStarts","blockSizes","qStarts","blockSizes",true)
				end 

				if(database == "all")
					mapper.output(@dbrcFile,@humanDB,tableIncrement,"#{@humanDir}#{fileName}",@doGzip,"tName","qName","blockCount","tStarts","blockSizes","qStarts","blockSizes",true)
					mapper.output(@dbrcFile,@mouseDB,tableIncrement,"#{@mouseDir}#{fileName}",@doGzip,"tName","qName","blockCount","tStarts","blockSizes","qStarts","blockSizes",true)
					mapper.output(@dbrcFile,@ratDB,tableIncrement,"#{@ratDir}#{fileName}",@doGzip,"tName","qName","blockCount","tStarts","blockSizes","qStarts","blockSizes",true)
				end
				
				chrom = chrom + 1
			end
			
			#---------Chromosome X
			tableIncrement = table.gsub(/N/,"X")
			
			if (@doGzip == true)
				fileName = tableIncrement + ".gz"
			else
				fileName = tableIncrement
			end
			
			#Human Database
			if(database == "human")
				mapper.output(@dbrcFile,@humanDB,tableIncrement,"#{@humanDir}#{fileName}",@doGzip,"tName","qName","blockCount","tStarts","blockSizes","qStarts","blockSizes",true)
			end
				
			#Mouse Database
			if(database == "mouse")
				mapper.output(@dbrcFile,@mouseDB,tableIncrement,"#{@mouseDir}#{fileName}",@doGzip,"tName","qName","blockCount","tStarts","blockSizes","qStarts","blockSizes",true)
			end
				
			#Rat Database
			if(database == "rat")
				mapper.output(@dbrcFile,@ratDB,tableIncrement,"#{@ratDir}#{fileName}",@doGzip,"tName","qName","blockCount","tStarts","blockSizes","qStarts","blockSizes",true)
			end 

			if(database == "all")
				mapper.output(@dbrcFile,@humanDB,tableIncrement,"#{@humanDir}#{fileName}",@doGzip,"tName","qName","blockCount","tStarts","blockSizes","qStarts","blockSizes",true)
				mapper.output(@dbrcFile,@mouseDB,tableIncrement,"#{@mouseDir}#{fileName}",@doGzip,"tName","qName","blockCount","tStarts","blockSizes","qStarts","blockSizes",true)
				mapper.output(@dbrcFile,@ratDB,tableIncrement,"#{@ratDir}#{fileName}",@doGzip,"tName","qName","blockCount","tStarts","blockSizes","qStarts","blockSizes",true)
			end
	
			#---------------- Chromosome Y
			tableIncrement = table.gsub(/N/,"Y")
			
			if (@doGzip == true)
				fileName = tableIncrement + ".gz"
			else
				fileName = tableIncrement
			end
			
			#Human Database
			if(database == "human")
				mapper.output(@dbrcFile,@humanDB,tableIncrement,"#{@humanDir}#{fileName}",@doGzip,"tName","qName","blockCount","tStarts","blockSizes","qStarts","blockSizes",true)
			end
				
			#Mouse Database
			if(database == "mouse")
				mapper.output(@dbrcFile,@mouseDB,tableIncrement,"#{@mouseDir}#{fileName}",@doGzip,"tName","qName","blockCount","tStarts","blockSizes","qStarts","blockSizes",true)
			end
				
			#Rat Database
			if(database == "rat")
				mapper.output(@dbrcFile,@ratDB,tableIncrement,"#{@ratDir}#{fileName}",@doGzip,"tName","qName","blockCount","tStarts","blockSizes","qStarts","blockSizes",true)
			end 

			if(database == "all")
				mapper.output(@dbrcFile,@humanDB,tableIncrement,"#{@humanDir}#{fileName}",@doGzip,"tName","qName","blockCount","tStarts","blockSizes","qStarts","blockSizes",true)
				mapper.output(@dbrcFile,@mouseDB,tableIncrement,"#{@mouseDir}#{fileName}",@doGzip,"tName","qName","blockCount","tStarts","blockSizes","qStarts","blockSizes",true)
				mapper.output(@dbrcFile,@ratDB,tableIncrement,"#{@ratDir}#{fileName}",@doGzip,"tName","qName","blockCount","tStarts","blockSizes","qStarts","blockSizes",true)
			end
		
		else
			if (@doGzip == true)
				fileName = table + ".gz"
			else
				fileName = table
			end
						
			#Human Database
			if(database == "human")
			 	mapper.output(@dbrcFile,@humanDB,table,"#{@humanDir}#{fileName}",@doGzip,"tName","qName","blockCount","tStarts","blockSizes","qStarts","blockSizes",true)
			end
			
			#Mouse Database
			if(database == "mouse")
				mapper.output(@dbrcFile,@mouseDB,table,"#{@mouseDir}#{fileName}",@doGzip,"tName","qName","blockCount","tStarts","blockSizes","qStarts","blockSizes",true)
			end
			
			#Rat Database
			if(database == "rat")
				mapper.output(@dbrcFile,@ratDB,table,"#{@ratDir}#{fileName}",@doGzip,"tName","qName","blockCount","tStarts","blockSizes","qStarts","blockSizes",true)
			end
			
			if(database == "all")
				mapper.output(@dbrcFile,@humanDB,table,"#{@humanDir}#{fileName}",@doGzip,"tName","qName","blockCount","tStarts","blockSizes","qStarts","blockSizes",true)
				mapper.output(@dbrcFile,@mouseDB,table,"#{@mouseDir}#{fileName}",@doGzip,"tName","qName","blockCount","tStarts","blockSizes","qStarts","blockSizes",true)
				mapper.output(@dbrcFile,@ratDB,table,"#{@ratDir}#{fileName}",@doGzip,"tName","qName","blockCount","tStarts","blockSizes","qStarts","blockSizes",true)
			end
		end
	end
	
end #UcscExporter

end; end #module BRL; module SQL
