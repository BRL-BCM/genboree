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
 #addList
 #my $inputIds = '1112_g_at,1331_s_at,1355_g_at,1372_at,1391_s_at,1403_s_at,1419_g_at,1575_at,1645_at,1786_at,1855_at,1890_at,1901_s_at,1910_s_at,1937_at,1974_s_at,1983_at,2090_i_at,31506_s_at,31512_at,31525_s_at,31576_at,31621_s_at,31687_f_at,31715_at,31793_at,31987_at,32010_at,32073_at,32084_at,32148_at,32163_f_at,32250_at,32279_at,32407_f_at,32413_at,32418_at,32439_at,32469_at,32680_at,32717_at,33027_at,33077_at,33080_s_at,33246_at,33284_at,33293_at,33371_s_at,33516_at,33530_at,33684_at,33685_at,33922_at,33963_at,33979_at,34012_at,34233_i_at,34249_at,34436_at,34453_at,34467_g_at,34529_at,34539_at,34546_at,34577_at,34606_s_at,34618_at,34623_at,34629_at,34636_at,34703_f_at,34720_at,34902_at,34972_s_at,35038_at,35069_at,35090_g_at,35091_at,35121_at,35169_at,35213_at,35367_at,35373_at,35439_at,35566_f_at,35595_at,35648_at,35896_at,35903_at,35915_at,35956_s_at,35996_at,36234_at,36317_at,36328_at,36378_at,36421_at,36436_at,36479_at,36696_at,36703_at,36713_at,36766_at,37061_at,37096_at,37097_at,37105_at,37166_at,37172_at,37408_at,37454_at,37711_at,37814_g_at,37898_r_at,37905_r_at,37953_s_at,37954_at,37968_at,37983_at,38103_at,38128_at,38201_at,38229_at,38236_at,38482_at,38508_s_at,38604_at,38646_s_at,38674_at,38691_s_at,38816_at,38926_at,38945_at,38948_at,39094_at,39187_at,39198_s_at,39469_s_at,39511_at,39698_at,39908_at,40058_s_at,40089_at,40186_at,40271_at,40294_at,40317_at,40350_at,40553_at,40735_at,40790_at,40959_at,41113_at,41280_r_at,41489_at,41703_r_at,606_at,679_at,822_s_at,919_at,936_s_at,966_at';
 #my $idType = 'AFFYMETRIX_3PRIME_IVT_ID';
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
 #my $inputIds = '9313,10736,54469,64839,8502,337879,1519,30844,54469,4288,57448,1603,55081,961,55081,650,140733,776,134359,151887,1601,9950,57663,134359,5641,55612,3394,55024,4745,9950,9,8317,80723,9950,80723,81624,56938,23504,55612,64284,123624,57556,26047,840,134359,23328,22822,57214,3670,196513,1361,84284,9655,4745,840,22871,9378,4690,25940,1361,140836,10539,862,5602,136541,4690,9378,776,105,5101,56853,7026,7704,57795,90411,4690,56884,285848,1361,57214,5101,3356,56853,55024,162963,51574,11103,90141,79750';
 my $idType = 'ENSEMBL_GENE_ID';
 my $listName = 'make_up';
 my $listType=0;
 my $list = $soap ->addList($inputIds, $idType, $listName, $listType)->result;
  	print "\n$list of list was mapped\n"; 
 
 #set user defined categories 
 my $categories = $soap ->setCategories("abcd,BBID,BIOCARTA,COG_ONTOLOGY,INTERPRO,KEGG_PATHWAY,OMIM_DISEASE,PIR_SUPERFAMILY,SMART,SP_PIR_KEYWORDS,UP_SEQ_FEATURE")->result;
 #to user DAVID default categories, send empty string to setCategories():
 #my $categories = $soap ->setCategories("")->result;
 #print "\nValid categories: \n$categories\n\n";  
 my @category_strings =split(',', $categories);

open (tableReport, ">", "$ARGV[0]/tableReport.txt");
print tableReport "$idType\tGene Name\tSpecies";
foreach (@category_strings)
{
	print tableReport "\t$_";
}	
print tableReport "\n";

#test getTableRecords()
my $tableReport = $soap->getTableReport();
	my @tableRecords = $tableReport->paramsout;
  	print "\nTotal table records: ".(@tableRecords+1)."\n"; 
	my @tableRecordKeys = keys %{$tableReport->result};	
	my @tableRecordvalues = values %{$tableReport->result};	
		
	my @values = values %{$tableRecordvalues[3]};
	print tableReport "$values[0]";
	if (@values > 1) 
	{
		for $j ( 1 .. (@values-1))
		{
			#print "\ttableRecord[0].value[".$j."] = ".$values[$j]."\n";
			print tableReport ",$values[$j]";
		}
	}
	print tableReport "\t$tableRecordvalues[2]";
	print tableReport "\t$tableRecordvalues[4]";
	
	
	my @annotation = @{$tableRecordvalues[1]};
	my %annotation_hash;		
	for $k ( 0 .. (@annotation-1))
	{
	    my $term='';
	    my $id='';
	    my $terms_string='';
	    my @annotation_keys = keys %{$annotation[$k]};
	    my @annotation_values = values %{$annotation[$k]};
	    my @annotation_terms = @{$annotation_values[0]};
	    
	    if (@annotation_terms >1)
	    {	    	
	    	for $i (0 .. (@annotation_terms-1))
	    	{
	    	    ($id,$term)=split(/\$/, $annotation_terms[$i]);
	    	    $terms_string = $terms_string.$term.','; 
	    	}	    	 	    		    		    	
	    }else{	    		    	
	    	($id,$term) = split(/\$/,$annotation_values[0]);
	    	$terms_string = $term.',';
	    }		    	   
	   $annotation_hash{$annotation_values[1]} = $terms_string;	   		    
	}
	
 	#create HashTable for each annotation	    	
	foreach (@category_strings)
	{
		my $annotation_term = $annotation_hash{$_};
		print tableReport "\t$annotation_term";
	}
	print tableReport "\n";

	for $n (0 .. (@tableRecords-1))
	{
		my %annotation_hash;		
		my $itr = $n+1;
		my @tableRecordKeys = keys %{$tableRecords[$n]};	
		my @tableRecordvalues = values %{$tableRecords[$n]};			
		my @values = values %{$tableRecordvalues[3]};
		print tableReport "$values[0]";
		if (@values > 1) 
		{
			for $j ( 1 .. (@values-1))
			{
				#print "\ttableRecord[0].value[".$j."] = ".$values[$j]."\n";
				print tableReport ",$values[$j]";
			}
		}	
		print tableReport "\t$tableRecordvalues[2]";
		print tableReport "\t$tableRecordvalues[4]";
	
	
		my @annotation = @{$tableRecordvalues[1]};
		for $k ( 0 .. (@annotation-1))
		{
			
			my $terms_string='';
			my $term='';
			my $id='';
	    		my @annotation_keys = keys %{$annotation[$k]};
	    		my @annotation_values = values %{$annotation[$k]};
	    		my @annotation_terms = @{$annotation_values[0]};
	    		if (@annotation_terms >1)
	    		{	    			
	    			for $i (0 .. (@annotation_terms-1))
	    			{
	    	    			($id,$term)=split(/\$/, $annotation_terms[$i]);
	    	    			$terms_string = $terms_string.$term.','; 
	    			}	    	 	    		    		    	
	    		}else{
	    			($id,$term) = split(/\$/,$annotation_values[0]);
	    			$terms_string = $term.',';
	    		}		    	  		 
	  		 $annotation_hash{$annotation_values[1]} = $terms_string;	   		    
		}
		
		foreach (@category_strings)
		{
			#my $category_string=$_;
			my $annotation_term = $annotation_hash{$_};
			print tableReport "\t$annotation_term";
		}
		print tableReport "\n";
	}	   
	
close tableReport;
print "\ntableReport.txt generated\n";
}
__END__	
