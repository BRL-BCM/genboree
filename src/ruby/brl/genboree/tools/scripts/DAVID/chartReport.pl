#!/usr/bin/env perl 
  #use strict;
  #use warnings;
  use SOAP::Lite;
  use HTTP::Cookies;

  my $soap = SOAP::Lite                             
     -> uri('http://service.session.sample')                
     -> proxy('http://david.abcc.ncifcrf.gov/webservice/services/DAVIDWebService',
                cookie_jar => HTTP::Cookies->new(ignore_discard=>1));

 #user authentication by email address
 #For new user registration, go to http://david.abcc.ncifcrf.gov/webservice/register.htm
 my $check = $soap->authenticate('genboree_adm@genboree.org')->result;
  	print "\nUser authentication: $check\n";

 if (lc($check) eq "true") { 
 open(FH,"<$ARGV[0]/mappedIDs.txt");
 my $length = scalar(@genNames);
 my @gene = [];
 my $inputIds = "A1BG";
 my $count = 0;
 my $i = 0;
 foreach $line (<FH>)
 {
	        if($i >3000)
		{last;}
 		@gene = split(/\t/, $line);
		$inputIds = $inputIds.",".$gene[1];
		$count++;
		$i++;
 }

 
 #list conversion types
 my $conversionTypes = $soap ->getConversionTypes()->result;
	 print  "\nConversion Types: \n$conversionTypes\n"; 
	 
 #list all annotation category names
 #my $allCategoryNames= $soap ->getAllAnnotationCategoryNames()->result;	 	  	
 #print  "\nAll available annotation category names: \n$allCategoryNames\n"; 
 
 #addList
 #my $inputIds = 'SCN5A,LTBP3,STX2,ST3GAL2,C15orf56,PAK6,DOK6,WNT10A,CCDC81,MARVELD2,FOXF1,LRRC14,LRRC24,EBF2,PPP2R2A,KRT7,LECT1,CNIH3';
 my $idType = 'ENSEMBL_GENE_ID';
 my $listName = 'make_up';
 my $listType=0;
 my $list = $soap ->addList($inputIds, $idType, $listName, $listType)->result;
 print "\n$list of list was mapped\n"; 
  	
 #list all species  names
 my $allSpecies= $soap ->getSpecies()->result;	 	  	
 # print  "\nAll species: \n$allSpecies\n"; 
 #list current species  names
 my $currentSpecies= $soap ->getCurrentSpecies()->result;	 	  	
 #print  "\nCurrent species: \n$currentSpecies\n"; 

 #set user defined species 
 #my $species = $soap ->setCurrentSpecies("1")->result;

 #print "\nCurrent species: \n$species\n"; 
 
#set user defined categories 
 my $categories = $soap ->setCategories("abcd,BBID,BIOCARTA,COG_ONTOLOGY,INTERPRO,KEGG_PATHWAY,OMIM_DISEASE,PIR_SUPERFAMILY,SMART,SP_PIR_KEYWORDS,UP_SEQ_FEATURE")->result;
 #to user DAVID default categories, send empty string to setCategories():
 #my $categories = $soap ->setCategories("")->result;
 #print "\nValid categories: \n$categories\n\n";  
 
open (chartReport, ">", "$ARGV[0]/chartReport.txt");
print chartReport "Category\tTerm\tCount\t%\tPvalue\tGenes\tList Total\tPop Hits\tPop Total\tFold Enrichment\tBonferroni\tBenjamini\tFDR\n";
#close chartReport;

#open (chartReport, ">>", "chartReport.txt");
#getChartReport 	
my $thd=0.1;
my $ct = 2;
my $chartReport = $soap->getChartReport($thd,$ct);
	my @chartRecords = $chartReport->paramsout;
	#shift(@chartRecords,($chartReport->result));
	#print $chartReport->result."\n";
  	print "Total chart records: ".(@chartRecords+1)."\n";
  	print "\n ";
	#my $retval = %{$chartReport->result};
	
	my @chartRecordKeys = keys %{$chartReport->result};
	
	#print "@chartRecordKeys\n";
	
	my @chartRecordValues = values %{$chartReport->result};
	
	my %chartRecord = %{$chartReport->result};
	my $categoryName = $chartRecord{"categoryName"};
	my $termName = $chartRecord{"termName"};
	my $listHits = $chartRecord{"listHits"};
	my $percent = $chartRecord{"percent"};
	my $ease = $chartRecord{"ease"};
	my $Genes = $chartRecord{"geneIds"};
	my $listTotals = $chartRecord{"listTotals"};
	my $popHits = $chartRecord{"popHits"};
	my $popTotals = $chartRecord{"popTotals"};
	my $foldEnrichment = $chartRecord{"foldEnrichment"};
	my $bonferroni = $chartRecord{"bonferroni"};
	my $benjamini = $chartRecord{"benjamini"};
	my $FDR = $chartRecord{"afdr"};
	
	print chartReport "$categoryName\t$termName\t$listHits\t$percent\t$ease\t$Genes\t$listTotals\t$popHits\t$popTotals\t$foldEnrichment\t$bonferroni\t$benjamini\t$FDR\n";
	
	
	for $j (0 .. (@chartRecords-1))
	{			
		%chartRecord = %{$chartRecords[$j]};
		$categoryName = $chartRecord{"categoryName"};
		$termName = $chartRecord{"termName"};
		$listHits = $chartRecord{"listHits"};
		$percent = $chartRecord{"percent"};
		$ease = $chartRecord{"ease"};
		$Genes = $chartRecord{"geneIds"};
		$listTotals = $chartRecord{"listTotals"};
		$popHits = $chartRecord{"popHits"};
		$popTotals = $chartRecord{"popTotals"};
		$foldEnrichment = $chartRecord{"foldEnrichment"};
		$bonferroni = $chartRecord{"bonferroni"};
		$benjamini = $chartRecord{"benjamini"};
		$FDR = $chartRecord{"afdr"};			
		print chartReport "$categoryName\t$termName\t$listHits\t$percent\t$ease\t$Genes\t$listTotals\t$popHits\t$popTotals\t$foldEnrichment\t$bonferroni\t$benjamini\t$FDR\n";				 
	}		  	
	
	close chartReport;
	print "\nchartReport.txt generated\n";
} 
__END__
		
