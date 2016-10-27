Breakout
Efficient and scalable structural variation analysis tool
Authors:
  Cristian Coarfa
	Jeff Reid
	
1. Build
--------

Get the latest breakout version
Create a Makefile.include file, using the existing  Makefile.include.template as a template.
make
make install

2. Execute
-----------

a. Split SOLID F3 and R3 mappings files

solidFrontEnd.exe is a utility that takes as input a SOLID mappings file, and splits it into
multiple output files based on read id. The program attempts to balance the size
of the output files.
  --mapFile          | -m    ===> SOLID mappings file to analyze
  --numberOfParts    | -n    ===> number of output parts (between 10 and 1024)
  --outputDirectory  | -o    ===> output directory
  --outputFileRoot   | -r    ===> output file root
	                               The output file names are going to be
                                 <output file root>.part.<part number>.
  --help             | -h    ===> print this help and exit

An usage example is
solidFrontEnd.exe -m F3_mappings_file -n 256 -o output_directory -r F3_output_file_root
solidFrontEnd.exe -m R3_mappings_file -n 256 -o output_directory -r R3_output_file_root

depending on the size of F3 and R3 mapping files, the number of parts to split might be chosen smaller than 256.

b. Compare each pair of split files, populating the consistent and inconsistent matepairs files


for i in $(seq 0 255)
do
  echo $i
	solidMatepairAnalyzer.exe -f F3_output_file_root.part.${i} -r R3_output_file_root.part.${i} -l minInsert -u maxInsert -o inconsistent_matepairs_root -c consistent_matepairs_root  -n 24 >> log.mpa. 2>&1
done

This step will generate files containing the consistent and inconsistent matepairs. For efficiency of further processing, the inconsistent matepairs output files are split
for pairs of distinct chromosomes.

c. Run the breakpoint caller
c.1. Ignoring repeats
    for f in inconsistent_matepairs_root*; do echo $f; breakCaller.exe -m $f -o bkps.$f -I maxInsert; done 
c.2. Take into account high-identity repeats
    for f in inconsistent_matepairs_root*; do echo $f; breakCaller.exe -m $f -o bkps.$f -I maxInsert -R hg18.90pIdentityRepeats; done 
c.3. Take into account low-identity repeats
    for f in inconsistent_matepairs_root*; do echo $f; breakCaller.exe -m $f -o bkps.$f -I maxInsert -R hg18.allRepeats; done 

d. Filter artifact breakpoints obtained due to amplification of the same genomic regions
    cat bkps.* > bkpsAll
		filterSameRead.rb bkpsAll bkpsSame.25 bkpsDiff.25 25

e. Convert breakpoints into a GFF compatible representation and call the different type of breakpoints
    sv-to-lff.rb -b bkpsDiff.25 -l bkpsDiff.lff -C class -T type -S subtype -m minInsert -M maxInsert

f. Generate a CSV-like representation of the breakpoints
    svlff2cvs.rb bkpsDiff.lff bkpsDiff.csv
