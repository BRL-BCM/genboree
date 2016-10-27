Small RNA Pipeline

PURPOSE
The purpose of the submitAccountForMappings ruby script is to create a PBS file
and submit it to the cluster. This script takes in a sequence file, reference
genome, and lff target, and a chromosome offset file. It runs through a series
of scripts that are used to take the small reads of RNA and find possible places
of interaction on the given genome. The results of that info of those scripts
are used to create a series of lff files and excel spreadsheet.

USE
To submit a set of reads to be analyzed by the small RNA pipeline use the
following command with the below options.

submitAnalyzeReads.rb
  -r  --readsFile  #reads file [Required]
  -o  --outputDir #output directory
  -t  --targetGenome #reference genome [Required]
  -k  --kWeight #kmer weight (default 11)
  -R  --refGenome # chromosome offset file [Required]
  -L  --lffFile # lff File for intersection
  -n  --maxMapping  #[optional] maximum number of mappings within
                            top percent of best score  (default 1). Reads
                            with a larger number of mappings that this
                            value are discarded from mapping results
  -i  --ignorePercent #Ignore percentage default 95
  -s  --scratch # scratch directory [Required]
  -d  --diagonals #number of diagonals, default 100
  -G  --gap #gap, default 6
  -P  --topPercent  #[optional] top percent of mappings to be kept
                            (default 1)
  
  -i  --ignorePercent #ignore below this percent
  -N  --nodes # processors per node, default 1
  -l  --kspan # kmer length (default 11)
  -v  --version #Version of the program
  -h  --help #Display help 


EXAMPLE
ruby submitAnalyzeReads.rb
  -r /home2/coarfa/forJeremy/provost/s_1_sequence_run79.fa
  -o /home1/eastonma/output/Issue-509-01
  -t /home2/coarfa/work/sequences/reference/Human18/sorted.ref.hg18.fa
  -R /home2/coarfa/hg18.off
  -L /home2/coarfa/work/sequences/reference/Human18/targets.kg.gr.mir.sno.sca.cp
g.piclus.hg18.lff
  -s .

CHANGELOG
2010-01-27 Extended small rna pipeline to generate fastq trimmed reads files
2010-02-11 Updated to reflect changes in the defaults
