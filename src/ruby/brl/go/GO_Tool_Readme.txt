BRL GO Tool

The BRL GO Tool was designed to classify gene sets on the basis of their classifications in the Gene Ontology database. 

Usage

tool.rb [-f] genelist

The program is located in //brl-depot/brl/src/ruby/brl/go in the Perforce directory structure. When the program is run for the first time, GO data is read from the GO database and is cached in files in the current working directory for faster access in subsequent uses of the program. Because this requires access to the database, a properly configured ".dbrc" file should be in the user's home directory. 

In order to make use of this feature, which should shorten run time by several minutes, use the -f flag as specified in the usage statement. 

"genelist" is a file, specified as a command-line argument, which contains the gene set. It should be a text file with each RefSeq accession number representing a gene in the gene set on a sepparate line. 

The program produces two output files. "notfound.txt" is a list of genes in the gene set which were not used in the analysis because they were not found in the GO database. 

The second file, "results.txt" is the results of the analysis. It is a tab-delimited text file which is easily viewable and manipulated in Excel or other programs. The first line of the file tells how many of the submitted genes were found in the database and used in the analysis. The second line contains column headings, and the following lines contain the data for each GO category which annotates genes in the gene set. The categories are in no particular order and can be sorted easily in Excel by relevent columns. 

Here is a brief description of each column:

Term:	The GO term. 
Sample Hits:	The number of genes in the gene set that were annotated with this GO term. 
Sample Total:	The total number of genes in the gene set which are found in the GO database. 
Sample Ratio:	The proportion of genes in the gene set which are annotated with this GO term. 
Population Hits:	The number of genes in the database which are annotated with this GO term. 
Population Total:	The total number of genes in the database. 
Population Ratio:	The proportion of genes in the database which are annotated with this GO term. 
Sample to Population Ratio: The Sample Ratio divided by the Population Ratio. This is a simple measure of enrichment, but is biased towards smaller GO categories. 
Enrichment:	A p-value as calculated by the hypergeometric distribution. The probablity that the current observation is due to chance. Smaller p-values represent greater enrichment for that GO term. 
Corrected Enrichment:	Enrichment multiplied by the number of tests (categories). Because we are carrying out multiple tests on the same data, the chances of making an error are higher. This correction gives more meaningful p-values and is the best measure of enrichment. 