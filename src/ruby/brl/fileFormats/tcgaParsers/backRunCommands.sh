#!/bin/bash

####### Programs
VALIDATOR="/usr/local/brl/local/apache/ruby/brl/fileFormats/tcgaParsers/validators.rb"
LFFGENERATOR="/usr/local/brl/local/apache/ruby/brl/fileFormats/tcgaParsers/lffGenerator.rb"
MAPPING="/usr/local/brl/local/apache/ruby/brl/fileFormats/tcgaParsers/mappingFilesGenerator.rb"
SAMPLESTATS="/usr/local/brl/local/apache/ruby/brl/fileFormats/tcgaParsers/sampleStats.rb"
MODIFYLFFS="/usr/local/brl/local/apache/ruby/brl/fileFormats/tcgaParsers/modifyLffs.rb"
GAPGENERATOR="/usr/local/brl/local/apache/ruby/brl/fileFormats/tcgaParsers/gapFileGenerator.rb"
SUMMARYGENERATOR="/usr/local/brl/local/apache/ruby/brl/fileFormats/tcgaParsers/summaryGenerator.rb"


############ Missing Files
missingAmpliconToLoci="missingA2Loci.missing"
missingAmpliconToRois="missingA2Roi.missing"
missingRoiToLoci="missingR2Loci.missing"

############ Duplicated Files
duplicatedRoiToLoci="dupR2Loci.duplicated"
duplicatedAmpliconToRois="dupA2Roi.duplicated"
duplicatedAmpliconToLoci="dupA2Loci.duplicated"

####### Mapping Files
ampliconToRoi="ampliconToRoi.map"
roiToLoci="roiToLoci.map"
ampliconToLociFileName="ampliconToLoci.map"
roiToCoverage="roiToCoverage.map"
ampliconToTotal="ampliconCompletion.summary"
sampleToTotal="sampleCompletion.summary"
geneSummaryFile="geneCoverage.summary"
geneCompletionFile="geneCompletion.summary"
########## Big table file
sampleAmpliconTableFile="sampleAmpliconTable.table"

######## Lff Files
ampliconLffFileName="amplicons.lff"
primerLffFileName="primers.lff"
roiLffFileName="roi.lff"
roiSequencingLffFileName="roiSequencing.lff"
gapFileName="gaps.lff"
tempFile="temp.lff"
ampliconSequencingFileName="Amplicon_Sequencing_File.txt.gz"
ampliconSeqLffFileName="ampliconSeq.lff"


 
if [ $# -lt 7 ]
then
  echo "usage: $0 AMPLICON_FILE ROI_FILE SAMPLE_FILE SAMPLESEQUENCING_FILE ROISEQUENCING_FILE LOCI_FILE INSTITUTION"
  exit
fi

baseDir=`pwd`


########### list of genes
listOfGenesFileName="listOfGenes.txt"
################ INPUT Files from Centers
ampliconFile=$1
roiFile=$2
sampleFile=$3
sampleSequencing=$4
roiSequence=$5
lociFile=$6
institution=$7

############### Variables
CLASSNAME=$institution"-Report-Data"
TYPE=$institution
ampliconSubtype="amplicon"
primerSubtype="primer"
roiSubtype="roi"
attributeName="perc1xCoverage"
gapCutOff="0.001"
gapSubtype="gaps"
fileCompletionPrefix="geneCompletion"
fileCompletionSubFix="report"
columnCompletionNumber="4"
numberOfColumnsCompletion="5"
fileOneXCoveragePrefix="geneOneXCoverage"
fileTwoXCoveragePrefix="geneTwoXCoverage"
fileCoverageSubFix="report"
columnOneXCoverageNumber="3"
columnTwoXCoverageNumber="4"
numberOfColumnsCoverage="5"
sampleCompletionPrefix="sampleCompletion"
sampleCompletionSubFix="report"
columnSampleCompletionNumber="3"
numberOfColumnsSampleCompletion="4"
sampleAmpliconCompletionPrefix="ampliconCompletion"
sampleAmpliconCompletionSubFix="report"
columnSampleAmpliconCompletionNumber="3"
numberOfColumnsSampleAmpliconCompletion="4"


##$VALIDATOR --roiFileName $roiFile --sampleFileName $sampleFile --ampliconFileName $ampliconFile  --sampleSequencingFileName $sampleSequencing --roiSequencingFileName $roiSequence
localDate=`date +'%Y-%m-%d @ %H:%M:%S (%s)'`
echo "RUNNING LFF Generator -- "$localDate
$LFFGENERATOR --ampliconFileName $ampliconFile --type $TYPE --ampliconSubtype $ampliconSubtype \
--ampliconClassName $CLASSNAME --ampliconLffFileName $ampliconLffFileName --primerSubtype $primerSubtype \
--primerClassName $CLASSNAME --primerLffFileName $primerLffFileName --roiFileName $roiFile \
--roiSubtype $roiSubtype --roiClassName $CLASSNAME --roiLffFileName $roiLffFileName \
--roiSequencingLffFileName $roiSequencingLffFileName --roiSequencingFileName $roiSequence --roiSeqclassName $CLASSNAME \
--ampliconSequencingFileName $ampliconSequencingFileName --ampliconSeqLffFileName $ampliconSeqLffFileName --ampliconSeqclassName $CLASSNAME
## Generates the amplicons.lff, roi.lff, primers.lff, roiSequencing.lff

localDate=`date +'%Y-%m-%d @ %H:%M:%S (%s)'`
echo "RUNNING Mapping Generator -- "$localDate
$MAPPING --ampliconLffFileName $ampliconLffFileName --roiLffFileName $roiLffFileName --ampliconToRoiFileName $ampliconToRoi \
--ampliconToRoiMissingFileName $missingAmpliconToRois --ampliconToRoiMultipleFileName $duplicatedAmpliconToRois \
--lociLffFileName $lociFile --roiToLociFileName $roiToLoci --roiToLociMissingFileName $missingRoiToLoci \
--roiToLociMultipleFileName $duplicatedRoiToLoci --ampliconToLociFileName $ampliconToLociFileName \
--ampliconToLociMissingFileName $missingAmpliconToLoci --ampliconToLociMultipleFileName $duplicatedAmpliconToLoci \
--roiSequencingFileName $roiSequence --roiTableFile $roiToCoverage --sampleFileName $sampleFile --listOfGenesFileName $listOfGenesFileName
## Generates the listOfGenes.txt missingFiles the duplicatedFiles and ampliconToRoi.map, roiToLoci.map, ampliconToLoci.map, roiToCoverage.map
## there are two or more entries in some cases many to many relationship

##exit
localDate=`date +'%Y-%m-%d @ %H:%M:%S (%s)'`
echo "RUNNING Sample Stats Generator -- "$localDate
$SAMPLESTATS --sampleSequencingFileName $sampleSequencing --ampliconFileName  $ampliconFile --sampleFileName $sampleFile \
--sampleAmpliconTableFile $sampleAmpliconTableFile --totalAmpliconFile $ampliconToTotal \
--totalSampleFile $sampleToTotal --sampleCompletionPrefix $sampleCompletionPrefix --sampleCompletionSubFix $sampleCompletionSubFix \
--columnSampleCompletionNumber $columnSampleCompletionNumber --numberOfColumnsSampleCompletion $numberOfColumnsSampleCompletion \
--sampleAmpliconCompletionPrefix $sampleAmpliconCompletionPrefix --sampleAmpliconCompletionSubFix $sampleAmpliconCompletionSubFix \
--columnAmpliconSampleCompletionNumber $columnSampleAmpliconCompletionNumber --numberOfColumnsSampleAmpliconCompletion $numberOfColumnsSampleAmpliconCompletion
## Generates the sampleAmpliconTable.table,sampleCompletion.summary, ampliconCompletion.summary, sampleCompletion, ampliconCompletion




localDate=`date +'%Y-%m-%d @ %H:%M:%S (%s)'`
echo "RUNNING LFF Modifiers  -- "$localDate
$MODIFYLFFS --tabDelimitedFileName $roiToLoci --lffFileName $roiLffFileName --outPutFileName $tempFile
mv $tempFile $roiLffFileName
$MODIFYLFFS --tabDelimitedFileName $roiToCoverage --lffFileName $roiLffFileName --outPutFileName $tempFile
mv $tempFile $roiLffFileName
$MODIFYLFFS --tabDelimitedFileName $ampliconToRoi --lffFileName $ampliconLffFileName --outPutFileName $tempFile
mv $tempFile $ampliconLffFileName
$MODIFYLFFS --tabDelimitedFileName $ampliconToLociFileName --lffFileName $ampliconLffFileName --outPutFileName $tempFile
mv $tempFile $ampliconLffFileName
$MODIFYLFFS --tabDelimitedFileName $ampliconToTotal --lffFileName $ampliconLffFileName --outPutFileName $tempFile
mv $tempFile $ampliconLffFileName
#modified the lffs roi.lff and amplicons.lff


echo "RUNNING GAPS Generator  ---- "
$GAPGENERATOR --roiLffFileName $roiLffFileName --gapLffFile $gapFileName --attributeName $attributeName \
--attributeThreshold $gapCutOff --subtype $gapSubtype
#created the gap file

localDate=`date +'%Y-%m-%d @ %H:%M:%S (%s)'`
echo "RUNNING SUMMARY Generator  ---- "$localDate
$SUMMARYGENERATOR --roiLffFileName $roiLffFileName --classType CountPerCoverage --attNameToUseForGrouping geneName \
--geneCoverageFileName $geneSummaryFile --ampliconLffFileName $ampliconLffFileName --sampleFileName $sampleFile \
--geneCompletionClassType CountPerAmpliconCompletion --geneCompletionFileName $geneCompletionFile \
--fileCompletionPrefix $fileCompletionPrefix --fileCompletionSubFix $fileCompletionSubFix \
--columnCompletionNumber $columnCompletionNumber --numberOfColumnsCompletion $numberOfColumnsCompletion \
--fileOneXCoveragePrefix $fileOneXCoveragePrefix --fileTwoXCoveragePrefix $fileTwoXCoveragePrefix \
--fileCoverageSubFix $fileCoverageSubFix --numberOfColumnsCoverage $numberOfColumnsCoverage \
--columnOneXCoverageNumber $columnOneXCoverageNumber --columnTwoXCoverageNumber $columnTwoXCoverageNumber --listOfGenesFileName $listOfGenesFileName
#generated the geneTwoXCoverage, geneOneXCoverage, geneCoverage.summary, geneCompletion.summary, geneCompletion

cd $baseDir
cd ampliconCompletion
for i in *.report; do result=`grep -v "^#" $i|wc -l`;name=`echo $i|sed -e 's/^[a-zA-Z]*_//' -e 's/.0-/-to-/' -e 's/.0_b.report//'`; printf "%s\t%s\n" $name $result; done >results.txt

cd $baseDir
cd geneCompletion
for i in *.report; do result=`grep -v "^#" $i|wc -l`;name=`echo $i|sed -e 's/^[a-zA-Z]*_//' -e 's/.0-/-to-/' -e 's/.0_b.report//'`; printf "%s\t%s\n" $name $result; done >results.txt

cd $baseDir
cd geneOneXCoverage
for i in *.report; do result=`grep -v "^#" $i|wc -l`;name=`echo $i|sed -e 's/^[a-zA-Z]*_//' -e 's/.0-/-to-/' -e 's/.0_b.report//'`; printf "%s\t%s\n" $name $result; done >results.txt

cd $baseDir
cd geneTwoXCoverage
for i in *.report; do result=`grep -v "^#" $i|wc -l`;name=`echo $i|sed -e 's/^[a-zA-Z]*_//' -e 's/.0-/-to-/' -e 's/.0_b.report//'`; printf "%s\t%s\n" $name $result; done >results.txt

cd $baseDir
cd sampleCompletion
for i in *.report; do result=`grep -v "^#" $i|wc -l`;name=`echo $i|sed -e 's/^[a-zA-Z]*_//' -e 's/.0-/-to-/' -e 's/.0_b.report//'`; printf "%s\t%s\n" $name $result; done >results.txt
#create the results inside the subdirectories the file is results.txt




localDate=`date +'%Y-%m-%d @ %H:%M:%S (%s)'`
echo "The End  --"$localDate

