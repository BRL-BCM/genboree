#!/usr/bin/env ruby
$VERBOSE = 1

=begin
This file implements the class UcscSqlExporter within the *BRL::SQL* module.

*UcscSqlExporter* uses the class SqlToSql to export data from a UCSC database table to the Genboree database.  

*UcscSqlExporter* has the following settable properties:
	dbrcFile - The location of a dbrc file containing login information for the databases.
	humanDB - The name of the UCSC human database.
	mouseDB - The name of the UCSC mouse database.
	ratDB - The name of the UCSC rat database.
	outputDB - The name of the Genboree database.
	
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
	table - The name of the table to be exported from the database.  If the table name is in the chrN format each 
		table will be migrated.
	classId - The class to be included in the Genboree database.
	type - The type to be included in the Genboree database.
	subtype - The subtype to be included in the Genboree database.

Author: Alan Harris <rharris1@bcm.tmc.edu>
Date  : March 13, 2003
=end

require 'sqlToSql'

module BRL; module SQL

class UcscSqlExporter

	attr_accessor :dbrcFile, :humanDB, :mouseDB, :ratDB

	def initialize
		@dbrcFile = "/users/hgsc/rharris1/.dbrc.rharris1"

		@humanDB = "andrewj_ucsc_hg13"
		@mouseDB = "andrewj_ucsc_mm2"
		@ratDB = "andrewj_ucsc_rn1"
		
		@outputDB = "genboree"
		
		@chromosomes=["1","2","3","4","5","6","7","8","9","10","11","12","13","14","15","16","17","18","19","20","21","22","X","Y"]
		
	end
	
	def genePrediction(database,table,classID,type,subtype)
		classID = '"' + classID + '"'
		type = '"' + type + '"'
		subtype = '"' + subtype + '"'
				
		fgroupMap = ["Source Op Dest","#{classID} constant gclass","name -> gname"]
		fgroupMapper = BRL::SQL::SqlToSql.new(fgroupMap)

		ftypeMap = ["Source Op Dest","#{type} constant fmethod","#{subtype} constant fsource"]
		ftypeMapper = BRL::SQL::SqlToSql.new(ftypeMap)
	  	
		#Human Database
		if (database == "human")
			#Insert group and place id in groupID
			groupID = fgroupMapper.output(@dbrcFile,@humanDB,table,@outputDB,"fgroup","chrom","name")
									
			#Insert type and place id in typeID	
			typeID = ftypeMapper.output(@dbrcFile,@humanDB,table,@outputDB,"ftype")
			
			typeID = typeID.to_s
			typeID = '"' + typeID + '"'		
			
			fdataMap = ["Source Op Dest","chrom -> fref","exonStarts -> fstart","exonEnds -> fstop",'fbin -> fbin',"#{typeID} constant ftypeid",'"." constant fscore',"strand -> fstrand",'"." constant fphase','"groupID" constant gid']
			fdataMapper = BRL::SQL::SqlToSql.new(fdataMap,4,"Hs-",groupID,"groupID")
			fdataMapper.output(@dbrcFile,@humanDB,table,@outputDB,"fdata","chrom","name","exonCount","exonStarts","exonEnds")
		
		#Mouse Database
		elsif (database == "mouse")
			#Insert group and place id in groupID
			groupID = fgroupMapper.output(@dbrcFile,@mouseDB,table,@outputDB,"fgroup","chrom","name")
									
			#Insert type and place id in typeID	
			typeID = ftypeMapper.output(@dbrcFile,@mouseDB,table,@outputDB,"ftype")
			
			typeID = typeID.to_s
			typeID = '"' + typeID + '"'		
			
			fdataMap = ["Source Op Dest","chrom -> fref","exonStarts -> fstart","exonEnds -> fstop",'fbin -> fbin',"#{typeID} constant ftypeid",'"." constant fscore',"strand -> fstrand",'"." constant fphase','"groupID" constant gid']
			fdataMapper = BRL::SQL::SqlToSql.new(fdataMap,4,"Mm-",groupID,"groupID")
			fdataMapper.output(@dbrcFile,@mouseDB,table,@outputDB,"fdata","chrom","name","exonCount","exonStarts","exonEnds")
						
		#Rat Database
		elsif (database == "rat")
			#Insert group and place id in groupID
			groupID = fgroupMapper.output(@dbrcFile,@ratDB,table,@outputDB,"fgroup","chrom","name")
									
			#Insert type and place id in typeID	
			typeID = ftypeMapper.output(@dbrcFile,@ratDB,table,@outputDB,"ftype")
			
			typeID = typeID.to_s
			typeID = '"' + typeID + '"'		
			
			fdataMap = ["Source Op Dest","chrom -> fref","exonStarts -> fstart","exonEnds -> fstop",'fbin -> fbin',"#{typeID} constant ftypeid",'"." constant fscore',"strand -> fstrand",'"." constant fphase','"groupID" constant gid']
			fdataMapper = BRL::SQL::SqlToSql.new(fdataMap,4,"Rn-",groupID,"groupID")
			fdataMapper.output(@dbrcFile,@ratDB,table,@outputDB,"fdata","chrom","name","exonCount","exonStarts","exonEnds")
		end
	end
	
	def genePredictionFlat(database,table,classID,type,subtype)
		classID = '"' + classID + '"'
		type = '"' + type + '"'
		subtype = '"' + subtype + '"'
				
		fgroupMap = ["Source Op Dest","#{classID} constant gclass","geneName -> gname"]
		fgroupMapper = BRL::SQL::SqlToSql.new(fgroupMap)

		ftypeMap = ["Source Op Dest","#{type} constant fmethod","#{subtype} constant fsource"]
		ftypeMapper = BRL::SQL::SqlToSql.new(ftypeMap)
		
		#Human Database
		if (database == "human")
			#Insert group and place id in groupID
			groupID = fgroupMapper.output(@dbrcFile,@humanDB,table,@outputDB,"fgroup","chrom","geneName")
									
			#Insert type and place id in typeID	
			typeID = ftypeMapper.output(@dbrcFile,@humanDB,table,@outputDB,"ftype")
			
			typeID = typeID.to_s
			typeID = '"' + typeID + '"'		
			
			fdataMap = ["Source Op Dest","chrom -> fref","exonStarts -> fstart","exonEnds -> fstop",'fbin -> fbin',"#{typeID} constant ftypeid",'"." constant fscore',"strand -> fstrand",'"." constant fphase','"groupID" constant gid']
			fdataMapper = BRL::SQL::SqlToSql.new(fdataMap,4,"Hs-",groupID,"groupID")
			fdataMapper.output(@dbrcFile,@humanDB,table,@outputDB,"fdata","chrom","geneName","exonCount","exonStarts","exonEnds")
		
		#Mouse Database
		elsif (database == "mouse")
			#Insert group and place id in groupID
			groupID = fgroupMapper.output(@dbrcFile,@mouseDB,table,@outputDB,"fgroup","chrom","geneName")
									
			#Insert type and place id in typeID	
			typeID = ftypeMapper.output(@dbrcFile,@mouseDB,table,@outputDB,"ftype")
			
			typeID = typeID.to_s
			typeID = '"' + typeID + '"'		
			
			fdataMap = ["Source Op Dest","chrom -> fref","exonStarts -> fstart","exonEnds -> fstop",'fbin -> fbin',"#{typeID} constant ftypeid",'"." constant fscore',"strand -> fstrand",'"." constant fphase','"groupID" constant gid']
			fdataMapper = BRL::SQL::SqlToSql.new(fdataMap,4,"Mm-",groupID,"groupID")
			fdataMapper.output(@dbrcFile,@mouseDB,table,@outputDB,"fdata","chrom","geneName","exonCount","exonStarts","exonEnds")
				
		#Rat  Database
		elsif(database == "rat")
			#Insert group and place id in groupID
			groupID = fgroupMapper.output(@dbrcFile,@ratDB,table,@outputDB,"fgroup","chrom","geneName")
									
			#Insert type and place id in typeID	
			typeID = ftypeMapper.output(@dbrcFile,@ratDB,table,@outputDB,"ftype")
			
			typeID = typeID.to_s
			typeID = '"' + typeID + '"'		
			
			fdataMap = ["Source Op Dest","chrom -> fref","exonStarts -> fstart","exonEnds -> fstop",'fbin -> fbin',"#{typeID} constant ftypeid",'"." constant fscore',"strand -> fstrand",'"." constant fphase','"groupID" constant gid']
			fdataMapper = BRL::SQL::SqlToSql.new(fdataMap,4,"Rn-",groupID,"groupID")
			fdataMapper.output(@dbrcFile,@ratDB,table,@outputDB,"fdata","chrom","geneName","exonCount","exonStarts","exonEnds")
		end
	end
	
	def mRNA_EST_Blat(database,table,classID,type,subtype)
		
		type = '"' + type + '"'
		subtype = '"' + subtype + '"'
		
		ftypeMap = ["Source Op Dest","#{type} constant fmethod","#{subtype} constant fsource"]
		ftypeMapper = BRL::SQL::SqlToSql.new(ftypeMap)
		
		#Insert type and place id in typeID
		typeID = ftypeMapper.output(@dbrcFile,nil,nil,@outputDB,"ftype")
					
		typeID = typeID.to_s
		typeID = '"' + typeID + '"'
		
		fdataMap = ["Source Op Dest","tName -> fref","tStarts -> fstart","blockSizes -> fstop",'fbin -> fbin',"#{typeID} constant ftypeid",'matches -> fscore',"strand -> fstrand",'"." constant fphase','"groupID" constant gid',"qStarts -> ftarget_start","blockSizes -> ftarget_stop"]
						
		if (table =~ /^chrN/)
								
			#Chromosomes 1-22, X and Y
			@chromosomes.each {
				|chromosome|
				
				tableIncrement = table.gsub(/N/,chromosome)
				
				classIDIncrement = '"' + classID + chromosome + '"'
				
				fgroupMap = ["Source Op Dest","#{classIDIncrement} constant gclass","qName -> gname"]
				fgroupMapper = BRL::SQL::SqlToSql.new(fgroupMap)
								
				#Human Database
				if(database == "human")
					
					#Insert group and place id in groupID
					groupID = fgroupMapper.output(@dbrcFile,@humanDB,tableIncrement,@outputDB,"fgroup","tName","qName")
										
					fdataMapper = BRL::SQL::SqlToSql.new(fdataMap,4,"Hs-",groupID,"groupID")
					fdataMapper.output(@dbrcFile,@humanDB,tableIncrement,@outputDB,"fdata","tName","qName","blockCount","tStarts","blockSizes","qStarts","blockSizes",true)
								
				#Mouse Database
				elsif(database == "mouse")
										
					#Insert group and place id in groupID
					groupID = fgroupMapper.output(@dbrcFile,@mouseDB,tableIncrement,@outputDB,"fgroup","tName","qName")
										
					fdataMapper = BRL::SQL::SqlToSql.new(fdataMap,4,"Mm-",groupID,"groupID")
					fdataMapper.output(@dbrcFile,@mouseDB,tableIncrement,@outputDB,"fdata","tName","qName","blockCount","tStarts","blockSizes","qStarts","blockSizes",true)
				
				#Rat Database
				elsif(database == "rat")
										
					#Insert group and place id in groupID
					groupID = fgroupMapper.output(@dbrcFile,@ratDB,tableIncrement,@outputDB,"fgroup","tName","qName")
										
					fdataMapper = BRL::SQL::SqlToSql.new(fdataMap,4,"Rn-",groupID,"groupID")
					fdataMapper.output(@dbrcFile,@ratDB,tableIncrement,@outputDB,"fdata","tName","qName","blockCount","tStarts","blockSizes","qStarts","blockSizes",true)
				end
			}
			
		else #Single input table
			
			fgroupMap = ["Source Op Dest","#{classID} constant gclass","qName -> gname"]
			fgroupMapper = BRL::SQL::SqlToSql.new(fgroupMap)
			
			#Human Database
			if(database == "human")
			 	#Insert group and place id in groupID
				groupID = fgroupMapper.output(@dbrcFile,@humanDB,tableIncrement,@outputDB,"fgroup","tName","qName")
										
				fdataMapper = BRL::SQL::SqlToSql.new(fdataMap,4,"Hs-",groupID,"groupID")
				fdataMapper.output(@dbrcFile,@humanDB,tableIncrement,@outputDB,"fdata","tName","qName","blockCount","tStarts","blockSizes","qStarts","blockSizes",true)
						
			#Mouse Database
			elsif(database == "mouse")
				#Insert group and place id in groupID
				groupID = fgroupMapper.output(@dbrcFile,@mouseDB,tableIncrement,@outputDB,"fgroup","tName","qName")
										
				fdataMapper = BRL::SQL::SqlToSql.new(fdataMap,4,"Mm-",groupID,"groupID")
				fdataMapper.output(@dbrcFile,@mouseDB,tableIncrement,@outputDB,"fdata","tName","qName","blockCount","tStarts","blockSizes","qStarts","blockSizes",true)
						
			#Rat Database
			elsif(database == "rat")
				#Insert group and place id in groupID
				groupID = fgroupMapper.output(@dbrcFile,@ratDB,tableIncrement,@outputDB,"fgroup","tName","qName")
										
				fdataMapper = BRL::SQL::SqlToSql.new(fdataMap,4,"Rn-",groupID,"groupID")
				fdataMapper.output(@dbrcFile,@ratDB,tableIncrement,@outputDB,"fdata","tName","qName","blockCount","tStarts","blockSizes","qStarts","blockSizes",true)
			end
		end
	end
	
end #UcscSqlExporter

end; end #module BRL; module SQL
