#!/usr/bin/env perl -w
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

 #yourEmail@your.org

 if (lc($check) eq "true") { 	
 #addList
 #WARNING: user should limit the number of genes in the list within 3000, or DAVID will turn down the service due to resource limitation.
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
 # my $inputIds = 'SCN5A,LTBP3,STX2,ST3GAL2,C15orf56,PAK6,DOK6,WNT10A,CCDC81,MARVELD2,FOXF1,LRRC14,LRRC24,EBF2,PPP2R2A,KRT7,LECT1,CNIH3';
 my $idType = 'ENSEMBL_GENE_ID';
 my $listName = 'make_up';
 my $listType=0;
 my $list = $soap ->addList($inputIds, $idType, $listName, $listType)->result;
  	print "\n$list of list was mapped\n"; 

 
 #set user defined categories 
 my $categories = $soap ->setCategories("abcd,BBID,BIOCARTA,COG_ONTOLOGY,INTERPRO,KEGG_PATHWAY,OMIM_DISEASE,PIR_SUPERFAMILY,SMART,SP_PIR_KEYWORDS,UP_SEQ_FEATURE")->result;
 #to user DAVID default categories, send empty string to setCategories():
 #my $categories = $soap ->setCategories("")->result;
 print "\nValid categories: \n$categories\n\n";  
 
open (termClusterReport, ">", "$ARGV[0]/termClusterReport.txt");

#test getTermClusterReport(int overlap,int initialSeed, int finalSeed, double linkage, int kappa)

my $overlap=3;
my $initialSeed = 2;
my $finalSeed = 2;
my $linkage = 0.5;
my $kappa = 20;
my $termClusterReport = $soap->getTermClusterReport($overlap,$initialSeed,$finalSeed,$linkage,$kappa);
#my $termClusterReport = $soap->getTermClusterReport();
	my @simpleTermClusterRecords = $termClusterReport->paramsout; 	
	print "Total TermClusterRecords: ".(@simpleTermClusterRecords+1)."\n\n"; 
	my @simpleTermClusterRecordKeys = keys %{$termClusterReport->result};		
	my @simpleTermClusterRecordValues = values %{$termClusterReport->result};
		
	@chartRecords = @{$simpleTermClusterRecordValues[1]};
	
	print termClusterReport "Annotation Cluster 1\tEnrichment Score:  $simpleTermClusterRecordValues[2]\n";
	print termClusterReport "Category\tTerm\tCount\t%\tPvalue\tGenes\tList Total\tPop Hits\tPop Total\tFold Enrichment\tBonferroni\tBenjamini\tFDR\n";
	for $j (0 .. (@chartRecords-1))
	{			
		%chartRecord = %{$chartRecords[$j]};	
			
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
		
		print termClusterReport "$categoryName\t$termName\t$listHits\t$percent\t$ease\t$Genes\t$listTotals\t$popHits\t$popTotals\t$foldEnrichment\t$bonferroni\t$benjamini\t$FDR\n";
	
	}	
	for $k (0 .. (@simpleTermClusterRecords-1))
	{	
		my $itr=$k+2;
		@simpleTermClusterRecordValues = values %{$simpleTermClusterRecords[$k]};
		@chartRecords = @{$simpleTermClusterRecordValues[1]};
		print termClusterReport "\nAnnotation Cluster $itr\tEnrichment Score:  $simpleTermClusterRecordValues[2]\n";
		print termClusterReport "Category\tTerm\tCount\t%\tPvalue\tGenes\tList Total\tPop Hits\tPop Total\tFold Enrichment\tBonferroni\tBenjamini\tFDR\n";
		for $j (0 .. (@chartRecords-1))
		{			
			%chartRecord = %{$chartRecords[$j]};
			
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
			
			print termClusterReport "$categoryName\t$termName\t$listHits\t$percent\t$ease\t$Genes\t$listTotals\t$popHits\t$popTotals\t$foldEnrichment\t$bonferroni\t$benjamini\t$FDR\n";		
		}
	}
	close termClusterReport;
	print "termClusterReport.txt generated\n";
}

__END__

#push(@simpleTermClusterRecords,$termClusterReport->result);
