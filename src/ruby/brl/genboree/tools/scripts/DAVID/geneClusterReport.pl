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
  	print "User authentication: $check\n";

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
 #addList
 #my $inputIds = 'SCN5A,LTBP3,STX2,ST3GAL2,C15orf56,PAK6,DOK6,WNT10A,CCDC81,MARVELD2,FOXF1,LRRC14,LRRC24,EBF2,PPP2R2A,KRT7,LECT1,CNIH3';
 my $idType = 'ENSEMBL_GENE_ID';
 my $listName = 'make_up';
 my $listType=0;
 my $list = $soap ->addList($inputIds, $idType, $listName, $listType)->result;
  	print "\n$list of list was mapped\n"; 

 
 #set user defined categories 
 my $categories = $soap ->setCategories("abcd,BBID,BIOCARTA,COG_ONTOLOGY,INTERPRO,KEGG_PATHWAY,OMIM_DISEASE,PIR_SUPERFAMILY,SMART,SP_PIR_KEYWORDS,UP_SEQ_FEATURE")->result;
 #to user DAVID default categories, send empty string to setCategories():
 #my $categories = $soap ->setCategories("")->result;
 print "\nValid categories: \n$categories\n";  	
 
open (geneClusterReport, ">", "$ARGV[0]/geneClusterReport.txt");

#test getGeneClusterReport()
my $overlap=3;
my $initialSeed = 2;
my $finalSeed = 2;
my $linkage = 0.5;
my $kappa = 35;
my $geneClusterReport = $soap->getGeneClusterReport($overlap,$initialSeed,$finalSeed,$linkage,$kappa);
	my @simpleGeneClusterRecords = $geneClusterReport->paramsout; 	
	print "Total SimpleGeneClusterRecords: ".(@simpleGeneClusterRecords+1)."\n\n"; 
	my @simpleGeneClusterRecordKeys = keys %{$geneClusterReport->result};		
	my @simpleGeneClusterRecordValues = values %{$geneClusterReport->result};	
	@listRecords = @{$simpleGeneClusterRecordValues[0]};	
	my $scoreValue=$simpleGeneClusterRecordValues[2];
	print geneClusterReport "Gene Group 1\tEnrichment Score:  $scoreValue\n";
	print geneClusterReport "ID\tGene Name\n";
	
	for $n ( 0 .. (@listRecords-1))
	{
		my @listRecords_keys = keys %{$listRecords[$n]};
		my @listRecords_values = values %{$listRecords[$n]};
		print geneClusterReport "$listRecords_values[2]\t$listRecords_values[1]\n";
		
	}
	
	
	for $k (0 .. (@simpleGeneClusterRecords-1))
	{
	
		my $itr = $k+2;	
		@simpleGeneClusterRecordKeys = keys %{$simpleGeneClusterRecords[$k]};	
	  	@simpleGeneClusterRecordValues = values %{$simpleGeneClusterRecords[$k]};
		$scoreValue=$simpleGeneClusterRecordValues[2];
		print geneClusterReport "\nGene Group $itr\tEnrichment Score:  $scoreValue\n";
		print geneClusterReport "ID\tGene Name\n";
		my @listRecords = @{$simpleGeneClusterRecordValues[0]};
						 			
		for $n ( 0 .. (@listRecords-1))
		{
			my @listRecords_keys = keys %{$listRecords[$n]};
			my @listRecords_values = values %{$listRecords[$n]};
			#print geneClusterReport "$listRecords_values[1]\t$listRecords_values[2]\n";
			print geneClusterReport "$listRecords_values[2]\t$listRecords_values[1]\n";
		}
		
	}
close geneClusterReport;
	 
print "\ngeneClusterReport.txt generated.\n"
}
